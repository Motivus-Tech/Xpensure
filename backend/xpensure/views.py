from rest_framework import status, permissions, generics, viewsets
from rest_framework.response import Response
from rest_framework.views import APIView
from .models import Employee, Reimbursement, AdvanceRequest
from rest_framework.authtoken.models import Token
from django.contrib.auth import get_user_model
from .serializers import (
    EmployeeSignupSerializer,
    ReimbursementSerializer,
    AdvanceRequestSerializer,
    EmployeeProfileSerializer,
    EmployeeHRCreateSerializer
)
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.authentication import TokenAuthentication
from django.contrib.auth import authenticate
from django.http import JsonResponse, HttpResponse
import csv
from django.utils import timezone
from datetime import timedelta
from rest_framework.response import Response
from django.db.models import Sum, Count, Q
from django.db import models 
import json 

User = get_user_model()


# -----------------------------
# Employee Signup (Self signup)
# -----------------------------
class EmployeeSignupView(APIView):
    permission_classes = [permissions.AllowAny]
    parser_classes = [MultiPartParser, FormParser]

    def post(self, request):
        serializer = EmployeeSignupSerializer(data=request.data)
        if not serializer.is_valid():
            return Response({"success": False, "errors": serializer.errors}, status=status.HTTP_400_BAD_REQUEST)

        employee = serializer.save()
        token, _ = Token.objects.get_or_create(user=employee)

        response_data = {
            "success": True,
            "employee_id": employee.employee_id,
            "email": employee.email,
            "fullName": employee.fullName,
            "department": employee.department,
            "phone_number": employee.phone_number,
            "aadhar_card": employee.aadhar_card,
            "role": employee.role,
            "report_to": employee.report_to,
            "avatar": request.build_absolute_uri(employee.avatar.url) if employee.avatar else None,
            "token": token.key
        }
        return Response(response_data, status=status.HTTP_201_CREATED)

# -----------------------------
# Employee Login
# -----------------------------
class EmployeeLoginView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        employee_id = request.data.get('employee_id')
        password = request.data.get('password')

        if not employee_id or not password:
            return Response(
                {'success': False, 'message': 'Both employee_id and password are required'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Use authenticate to check hashed password correctly
        user = authenticate(employee_id=employee_id, password=password)

        if user:
            token, _ = Token.objects.get_or_create(user=user)
            return Response({
                'success': True,
                'employee_id': user.employee_id,
                'fullName': user.fullName,
                'email': user.email,
                'department': user.department,
                'phone_number': user.phone_number,
                'aadhar_card': user.aadhar_card,
                'avatar': request.build_absolute_uri(user.avatar.url) if user.avatar else None,
                'role': user.role,
                'token': token.key
            }, status=status.HTTP_200_OK)
        else:
            return Response(
                {'success': False, 'message': 'Invalid credentials'},
                status=status.HTTP_401_UNAUTHORIZED
            )
# -----------------------------
# Reimbursement & Advance ViewSets
# -----------------------------
class ReimbursementViewSet(viewsets.ModelViewSet):
    serializer_class = ReimbursementSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Reimbursement.objects.filter(employee=self.request.user).order_by('-date')
    
    def perform_create(self, serializer):
        employee = self.request.user
        # agar employee ka report_to hai → Pending, warna Approved
        next_approver = employee.report_to if employee.report_to else None
        status = "Pending" if next_approver else "Approved"
        serializer.save(employee=employee, current_approver_id=next_approver, status=status)



class AdvanceRequestViewSet(viewsets.ModelViewSet):
    serializer_class = AdvanceRequestSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return AdvanceRequest.objects.filter(employee=self.request.user).order_by('-request_date')

    def perform_create(self, serializer):
        employee = self.request.user
    #  agar employee ka report_to hai → Pending, warna Approved
        next_approver = employee.report_to if employee.report_to else None
        status = "Pending" if next_approver else "Approved"
        serializer.save(employee=employee, current_approver_id=next_approver, status=status)

class ReimbursementListCreateView(generics.ListCreateAPIView):
    serializer_class = ReimbursementSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Reimbursement.objects.filter(employee=self.request.user)
    
    def perform_create(self, serializer):
        employee = self.request.user
    # agar employee ka report_to hai → Pending, warna Approved
        next_approver = employee.report_to if employee.report_to else None
        status = "Pending" if next_approver else "Approved"
        serializer.save(employee=employee, current_approver_id=next_approver, status=status)

   
class AdvanceRequestListCreateView(generics.ListCreateAPIView):
    serializer_class = AdvanceRequestSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return AdvanceRequest.objects.filter(employee=self.request.user)

    def perform_create(self, serializer):
        employee = self.request.user
    # agar employee ka report_to hai → Pending, warna Approved
        next_approver = employee.report_to if employee.report_to else None
        status = "Pending" if next_approver else "Approved"
        serializer.save(employee=employee, current_approver_id=next_approver, status=status)


# -----------------------------

# Employee Profile
# -----------------------------
class EmployeeProfileView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]

    def get_object(self, employee_id):
        try:
            return User.objects.get(employee_id=employee_id)
        except User.DoesNotExist:
            return None

    def get(self, request, employee_id):
        obj = self.get_object(employee_id)
        if obj is None:
            return Response({"detail": "Employee not found."}, status=status.HTTP_404_NOT_FOUND)
        if request.user != obj and not request.user.is_staff:
            return Response({"detail": "Not authorized."}, status=status.HTTP_403_FORBIDDEN)
        serializer = EmployeeProfileSerializer(obj, context={"request": request})
        return Response(serializer.data, status=status.HTTP_200_OK)

    def put(self, request, employee_id):
        obj = self.get_object(employee_id)
        if obj is None:
            return Response({"detail": "Employee not found."}, status=status.HTTP_404_NOT_FOUND)
        if request.user != obj and not request.user.is_staff:
            return Response({"detail": "Not authorized."}, status=status.HTTP_403_FORBIDDEN)
        serializer = EmployeeProfileSerializer(obj, data=request.data, partial=True, context={"request": request})
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data, status=status.HTTP_200_OK)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


# -----------------------------
# Verify & Change Password
# -----------------------------
class VerifyPasswordView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, employee_id):
        try:
            user = User.objects.get(employee_id=employee_id)
        except User.DoesNotExist:
            return Response({"detail": "Employee not found."}, status=status.HTTP_404_NOT_FOUND)
        if request.user != user and not request.user.is_staff:
            return Response({"detail": "Not authorized."}, status=status.HTTP_403_FORBIDDEN)
        old_password = request.data.get("old_password")
        if not old_password:
            return Response({"detail": "old_password field is required."}, status=status.HTTP_400_BAD_REQUEST)
        if user.check_password(old_password):
            return Response({"detail": "Password verified."}, status=status.HTTP_200_OK)
        else:
            return Response({"detail": "Incorrect password."}, status=status.HTTP_401_UNAUTHORIZED)


class ChangePasswordView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def put(self, request, employee_id):
        try:
            user = User.objects.get(employee_id=employee_id)
        except User.DoesNotExist:
            return Response({"detail": "Employee not found."}, status=status.HTTP_404_NOT_FOUND)
        if request.user != user and not request.user.is_staff:
            return Response({"detail": "Not authorized."}, status=status.HTTP_403_FORBIDDEN)
        new_password = request.data.get("new_password")
        if not new_password:
            return Response({"detail": "new_password is required."}, status=status.HTTP_400_BAD_REQUEST)
        if len(new_password) < 6:
            return Response({"detail": "New password must be at least 6 characters."}, status=status.HTTP_400_BAD_REQUEST)
        user.set_password(new_password)
        user.save()
        return Response({"detail": "Password changed successfully."}, status=status.HTTP_200_OK)


class EmployeeDeleteView(generics.DestroyAPIView):
    queryset = Employee.objects.all()
    serializer_class = EmployeeSignupSerializer
    permission_classes = [permissions.IsAuthenticated]
    lookup_field = "employee_id"

# -----------------------------
# HR: List & Create Employees
# -----------------------------
class EmployeeListCreateView(generics.ListCreateAPIView):
    queryset = User.objects.all()
    serializer_class = EmployeeHRCreateSerializer
    authentication_classes = [TokenAuthentication]
    permission_classes = [permissions.IsAdminUser]


# -----------------------------
# HR: Retrieve, Update, Delete Employee by employee_id
# -----------------------------
class EmployeeDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = User.objects.all()
    serializer_class = EmployeeHRCreateSerializer
    lookup_field = 'employee_id'
    authentication_classes = [TokenAuthentication]
    permission_classes = [permissions.IsAdminUser]

# -----------------------------
# Multi-level Approval Utilities - UPDATED
# -----------------------------
def get_next_approver(employee):
    """
    Returns the next approver based on report_to.
    Special handling for Finance role.
    """
    if not employee or not employee.report_to:
        return None
    
    try:
        next_approver = User.objects.get(employee_id=employee.report_to)
        
        # If next approver has Finance role, this is the finance approval step
        if next_approver.role == "Finance":
            return next_approver.employee_id
            
        # If next approver is CEO, this is the final approval
        if next_approver.role == "CEO":
            return next_approver.employee_id
            
        # Normal manager approval chain
        return next_approver.employee_id
        
    except User.DoesNotExist:
        return None
def process_approval(request_obj, approver_employee, approved=True, rejection_reason=None):
    """
    Handles approval/rejection for Reimbursement/AdvanceRequest
    """
    if not approved:
        request_obj.status = "Rejected"
        request_obj.rejection_reason = rejection_reason
        request_obj.current_approver_id = None
        request_obj.final_approver = approver_employee.employee_id
        request_obj.save()
        return request_obj

    # ✅ CEO APPROVAL - DIRECT FINAL APPROVAL
    if approver_employee.role == "CEO":
        request_obj.status = "Approved"
        request_obj.current_approver_id = None
        request_obj.approved_by_ceo = True
        request_obj.final_approver = approver_employee.employee_id
        request_obj.rejection_reason = None
        request_obj.save()
        return request_obj

    # ✅ FINANCE APPROVAL
    if approver_employee.role == "Finance":
        request_obj.approved_by_finance = True
        # After finance approval, go to CEO
        next_approver_id = get_next_approver(approver_employee)
        if next_approver_id:
            request_obj.current_approver_id = next_approver_id
            request_obj.status = "Pending"
        else:
            request_obj.status = "Approved"
            request_obj.current_approver_id = None
            request_obj.final_approver = approver_employee.employee_id

    # ✅ NORMAL MANAGER APPROVAL
    else:
        next_approver_id = get_next_approver(approver_employee)
        
        if next_approver_id:
            request_obj.current_approver_id = next_approver_id
            request_obj.status = "Pending"
            
            # Check if next approver is Finance
            try:
                next_approver = User.objects.get(employee_id=next_approver_id)
                if next_approver.role == "Finance":
                    request_obj.status = "Pending Finance"
            except User.DoesNotExist:
                pass
        else:
            # No next approver - final approval
            request_obj.status = "Approved"
            request_obj.current_approver_id = None
            request_obj.final_approver = approver_employee.employee_id
            request_obj.rejection_reason = None
    request_obj.save()
    return request_obj

# -----------------------------
# Approve / Reject APIs
# -----------------------------
class ApproveRequestAPIView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, request_id):
        request_type = request.data.get("request_type")
        if request_type == "reimbursement":
            obj = Reimbursement.objects.filter(id=request_id).first()
        elif request_type == "advance":
            obj = AdvanceRequest.objects.filter(id=request_id).first()
        else:
            return Response({"detail": "Invalid request_type"}, status=status.HTTP_400_BAD_REQUEST)
        if not obj:
            return Response({"detail": "Request not found"}, status=status.HTTP_404_NOT_FOUND)
        if obj.current_approver_id != request.user.employee_id:
            return Response({"detail": "Not authorized to approve"}, status=status.HTTP_403_FORBIDDEN)
        process_approval(obj, request.user, approved=True)
        return Response({"detail": "Request approved successfully."}, status=status.HTTP_200_OK)


class RejectRequestAPIView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, request_id):
        request_type = request.data.get("request_type")
        rejection_reason = request.data.get("rejection_reason")
        if not rejection_reason:
            return Response({"detail": "rejection_reason is required"}, status=status.HTTP_400_BAD_REQUEST)
        if request_type == "reimbursement":
            obj = Reimbursement.objects.filter(id=request_id).first()
        elif request_type == "advance":
            obj = AdvanceRequest.objects.filter(id=request_id).first()
        else:
            return Response({"detail": "Invalid request_type"}, status=status.HTTP_400_BAD_REQUEST)
        if not obj:
            return Response({"detail": "Request not found"}, status=status.HTTP_404_NOT_FOUND)
        if obj.current_approver_id != request.user.employee_id:
            return Response({"detail": "Not authorized to reject"}, status=status.HTTP_403_FORBIDDEN)
        process_approval(obj, request.user, approved=False, rejection_reason=rejection_reason)
        return Response({"detail": "Request rejected successfully."}, status=status.HTTP_200_OK)

class PendingApprovalsView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        # Requests where current user is approver
        reimbursements_to_approve = Reimbursement.objects.filter(
            current_approver_id=request.user.employee_id,
            status="Pending"
        )
        advances_to_approve = AdvanceRequest.objects.filter(
            current_approver_id=request.user.employee_id,
            status="Pending"
        )

        # ✅ FIXED: Get ALL requests created by current user (including ALL statuses - Pending, Approved, Rejected, Paid)
        reimbursements_created = Reimbursement.objects.filter(
            employee_id=request.user.employee_id
        ).order_by('-created_at')

        advances_created = AdvanceRequest.objects.filter(
            employee_id=request.user.employee_id  
        ).order_by('-created_at')

        data = {
            "reimbursements_to_approve": [
                {
                    "id": r.id,
                    "employee_id": r.employee_id,
                    "employee_name": r.employee.fullName if r.employee else None,
                    "employee_avatar": request.build_absolute_uri(r.employee.avatar.url) if r.employee and r.employee.avatar else None,
                    "date": r.date,
                    "amount": r.amount,
                    "description": r.description,
                    "payments": r.payments,
                    "status": r.status,
                    "rejection_reason": r.rejection_reason
                }
                for r in reimbursements_to_approve
            ],
            "advances_to_approve": [
                {
                    "id": a.id,
                    "employee_id": a.employee_id,
                    "employee_name": a.employee.fullName if a.employee else None,
                    "employee_avatar": request.build_absolute_uri(a.employee.avatar.url) if a.employee and a.employee.avatar else None,
                    "request_date": a.request_date,
                    "project_date": a.project_date,
                    "amount": a.amount,
                    "description": a.description,
                    "payments": a.payments,
                    "status": a.status,
                    "rejection_reason": a.rejection_reason
                }
                for a in advances_to_approve
            ],
            # ✅ FIXED: These now include ALL statuses permanently including "Paid"
            "my_reimbursements": [
                {
                    "id": r.id,
                    "employee_id": r.employee_id,
                    "date": r.date,
                    "amount": r.amount,
                    "description": r.description,
                    "payments": r.payments,
                    "status": r.status,
                    "rejection_reason": r.rejection_reason,
                    "created_at": r.created_at,
                    "updated_at": r.updated_at,
                    "payment_date": r.payment_date  # ✅ ADDED PAYMENT DATE
                }
                for r in reimbursements_created
            ],
            "my_advances": [
                {
                    "id": a.id,
                    "employee_id": a.employee_id,
                    "request_date": a.request_date,
                    "project_date": a.project_date,
                    "amount": a.amount,
                    "description": a.description,
                    "payments": a.payments,
                    "status": a.status,
                    "rejection_reason": a.rejection_reason,
                    "created_at": a.created_at,
                    "updated_at": a.updated_at,
                    "payment_date": a.payment_date  # ✅ ADDED PAYMENT DATE
                }
                for a in advances_created
            ],
        }
        
        return Response(data, status=status.HTTP_200_OK)
    
def health_check(request):
    return JsonResponse({"status": "ok"})
class FinanceDashboardView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        # Check if user has Finance role
        if request.user.role != "Finance":
            return Response(
                {"detail": "Access denied. Finance role required."}, 
                status=status.HTTP_403_FORBIDDEN
            )
        
        # Get requests where current Finance user is the approver (Pending for Finance approval)
        pending_finance_approval = []
        
        # Reimbursements pending Finance approval
        reimbursement_pending = Reimbursement.objects.filter(
            current_approver_id=request.user.employee_id,
            status__in=["Pending", "Pending Finance"]
        ).select_related('employee')
        
        for reimbursement in reimbursement_pending:
            pending_finance_approval.append({
                'id': reimbursement.id,
                'employee_id': reimbursement.employee.employee_id,
                'employee_name': reimbursement.employee.fullName,
                'employee_avatar': request.build_absolute_uri(reimbursement.employee.avatar.url) if reimbursement.employee.avatar else None,
                'date': reimbursement.date,
                'amount': float(reimbursement.amount),
                'description': reimbursement.description,
                'payments': reimbursement.payments if reimbursement.payments else [],
                'request_type': 'reimbursement',
                'status': reimbursement.status,
                "rejection_reason": reimbursement.rejection_reason
            })

        # Advances pending Finance approval
        advance_pending = AdvanceRequest.objects.filter(
            current_approver_id=request.user.employee_id,
            status__in=["Pending", "Pending Finance"]
        ).select_related('employee')
        
        for advance in advance_pending:
            pending_finance_approval.append({
                'id': advance.id,
                'employee_id': advance.employee.employee_id,
                'employee_name': advance.employee.fullName,
                'employee_avatar': request.build_absolute_uri(advance.employee.avatar.url) if advance.employee.avatar else None,
                'date': advance.request_date,
                'amount': float(advance.amount),
                'description': advance.description,
                'payments': advance.payments if advance.payments else [],
                'request_type': 'advance',
                'status': advance.status,
                "rejection_reason": advance.rejection_reason
            })

        # ✅ FIXED: CEO APPROVED REQUESTS FOR PAYMENT TAB
        ceo_approved = []
        
        # Get reimbursements that are approved and ready for payment
        reimbursement_ceo_approved = Reimbursement.objects.filter(
            status='Approved'
        ).select_related('employee')
        
        for reimbursement in reimbursement_ceo_approved:
            # Check if this was approved by CEO (current_approver_id is null after final approval)
            if reimbursement.current_approver_id is None:
                ceo_approved.append({
                    'id': reimbursement.id,
                    'employee_id': reimbursement.employee.employee_id,
                    'employee_name': reimbursement.employee.fullName,
                    'employee_avatar': request.build_absolute_uri(reimbursement.employee.avatar.url) if reimbursement.employee.avatar else None,
                    'date': reimbursement.date,
                    'amount': float(reimbursement.amount),
                    'description': reimbursement.description,
                    'payments': reimbursement.payments if reimbursement.payments else [],
                    'request_type': 'reimbursement',
                    'status': 'Approved',
                    'approved_by': 'CEO',
                    'approval_date': reimbursement.updated_at,
                    'rejection_reason': reimbursement.rejection_reason
                })

        # Get advances that are approved and ready for payment
        advance_ceo_approved = AdvanceRequest.objects.filter(
            status='Approved'
        ).select_related('employee')
        
        for advance in advance_ceo_approved:
            # Check if this was approved by CEO (current_approver_id is null after final approval)
            if advance.current_approver_id is None:
                ceo_approved.append({
                    'id': advance.id,
                    'employee_id': advance.employee.employee_id,
                    'employee_name': advance.employee.fullName,
                    'employee_avatar': request.build_absolute_uri(advance.employee.avatar.url) if advance.employee.avatar else None,
                    'date': advance.request_date,
                    'amount': float(advance.amount),
                    'description': advance.description,
                    'payments': advance.payments if advance.payments else [],
                    'request_type': 'advance',
                    'status': 'Approved',
                    'approved_by': 'CEO',
                    'approval_date': advance.updated_at,
                    "rejection_reason": advance.rejection_reason
                })

        # Counts for dashboard
        approved_count = Reimbursement.objects.filter(status='Approved').count() + AdvanceRequest.objects.filter(status='Approved').count()
        rejected_count = Reimbursement.objects.filter(status='Rejected').count() + AdvanceRequest.objects.filter(status='Rejected').count()

        return Response({
            'pending_finance_approval': pending_finance_approval,  # Requests waiting for Finance approval
            'ceo_approved': ceo_approved,  # ✅ FIXED: CEO approved requests for payment tab
            'approved_count': approved_count,
            'rejected_count': rejected_count,
            'pending_verification_count': len(pending_finance_approval),
            'pending_payment_count': len(ceo_approved)
        })
class FinanceApproveRequestView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        request_id = request.data.get('request_id')
        request_type = request.data.get('request_type')
        
        if not request_id or not request_type:
            return Response(
                {'error': 'request_id and request_type are required'},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            if request_type == 'reimbursement':
                reimbursement = Reimbursement.objects.get(id=request_id)
                # Check if current user is the approver
                if reimbursement.current_approver_id != request.user.employee_id:
                    return Response(
                        {'error': 'Not authorized to approve this request'},
                        status=status.HTTP_403_FORBIDDEN
                    )
                # Process approval through the workflow
                process_approval(reimbursement, request.user, approved=True)
                
                return Response({
                    'message': 'Reimbursement approved by finance successfully',
                    'status': reimbursement.status
                })
                
            elif request_type == 'advance':
                advance = AdvanceRequest.objects.get(id=request_id)
                # Check if current user is the approver
                if advance.current_approver_id != request.user.employee_id:
                    return Response(
                        {'error': 'Not authorized to approve this request'},
                        status=status.HTTP_403_FORBIDDEN
                    )
                # Process approval through the workflow
                process_approval(advance, request.user, approved=True)
                
                return Response({
                    'message': 'Advance approved by finance successfully',
                    'status': advance.status
                })
                
            else:
                return Response(
                    {'error': 'Invalid request type'},
                    status=status.HTTP_400_BAD_REQUEST
                )
                
        except (Reimbursement.DoesNotExist, AdvanceRequest.DoesNotExist):
            return Response(
                {'error': 'Request not found'},
                status=status.HTTP_404_NOT_FOUND
            )


class FinanceRejectRequestView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        request_id = request.data.get('request_id')
        request_type = request.data.get('request_type')
        reason = request.data.get('reason', '')
        
        if not request_id or not request_type:
            return Response(
                {'error': 'request_id and request_type are required'},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            if request_type == 'reimbursement':
                reimbursement = Reimbursement.objects.get(id=request_id)
                # Check if current user is the approver
                if reimbursement.current_approver_id != request.user.employee_id:
                    return Response(
                        {'error': 'Not authorized to reject this request'},
                        status=status.HTTP_403_FORBIDDEN
                    )
                # Process rejection through the workflow
                process_approval(reimbursement, request.user, approved=False, rejection_reason=reason)
                
                return Response({
                    'message': 'Reimbursement rejected by finance',
                    'status': reimbursement.status
                })
                
            elif request_type == 'advance':
                advance = AdvanceRequest.objects.get(id=request_id)
                # Check if current user is the approver
                if advance.current_approver_id != request.user.employee_id:
                    return Response(
                        {'error': 'Not authorized to reject this request'},
                        status=status.HTTP_403_FORBIDDEN
                    )
                # Process rejection through the workflow
                process_approval(advance, request.user, approved=False, rejection_reason=reason)
                
                return Response({
                    'message': 'Advance rejected by finance',
                    'status': advance.status
                })
                
            else:
                return Response(
                    {'error': 'Invalid request type'},
                    status=status.HTTP_400_BAD_REQUEST
                )
                
        except (Reimbursement.DoesNotExist, AdvanceRequest.DoesNotExist):
            return Response(
                {'error': 'Request not found'},
                status=status.HTTP_404_NOT_FOUND
            )


class MarkAsPaidView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        request_id = request.data.get('request_id')
        request_type = request.data.get('request_type')
        
        if not request_id or not request_type:
            return Response(
                {'error': 'request_id and request_type are required'},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            if request_type == 'reimbursement':
                reimbursement = Reimbursement.objects.get(id=request_id)
                reimbursement.status = 'Paid'
                reimbursement.payment_date = timezone.now()
                reimbursement.save()
                
                return Response({
                    'message': 'Reimbursement marked as paid',
                    'status': reimbursement.status
                })
                
            elif request_type == 'advance':
                advance = AdvanceRequest.objects.get(id=request_id)
                advance.status = 'Paid'
                advance.payment_date = timezone.now()
                advance.save()
                
                return Response({
                    'message': 'Advance marked as paid',
                    'status': advance.status
                })
                
            else:
                return Response(
                    {'error': 'Invalid request type'},
                    status=status.HTTP_400_BAD_REQUEST
                )
                
        except (Reimbursement.DoesNotExist, AdvanceRequest.DoesNotExist):
            return Response(
                {'error': 'Request not found'},
                status=status.HTTP_404_NOT_FOUND
            )


class GenerateFinanceReportView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        months = int(request.GET.get('months', 1))
        
        # Calculate date range
        end_date = timezone.now()
        start_date = end_date - timedelta(days=30*months)
        
        # Get reimbursements in date range
        reimbursements = Reimbursement.objects.filter(
            date__range=[start_date, end_date]
        ).select_related('employee')
        
        # Get advances in date range
        advances = AdvanceRequest.objects.filter(
            request_date__range=[start_date, end_date]
        ).select_related('employee')
        
        # Create CSV response
        response = HttpResponse(content_type='text/csv')
        response['Content-Disposition'] = f'attachment; filename="finance_report_{months}months.csv"'
        
        writer = csv.writer(response)
        writer.writerow([
            'ID', 'Employee ID', 'Employee Name', 'Request Type', 
            'Amount', 'Submission Date', 'Status', 'Description'
        ])
        
        # Write reimbursement data
        for reimbursement in reimbursements:
            writer.writerow([
                reimbursement.id,
                reimbursement.employee.employee_id,
                reimbursement.employee.fullName,
                'Reimbursement',
                reimbursement.amount,
                reimbursement.date,
                reimbursement.status,
                reimbursement.description
            ])
        
        # Write advance data
        for advance in advances:
            writer.writerow([
                advance.id,
                advance.employee.employee_id,
                advance.employee.fullName,
                'Advance',
                advance.amount,
                advance.request_date,
                advance.status,
                advance.description
            ])
        
        return response
  # Add these imports at the top of your views.py
from django.db.models import Sum, Count, Q
from django.db import models
import json

# -----------------------------
# CEO DASHBOARD VIEWS - FIXED
# -----------------------------

class CEODashboardView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        # Check if user is CEO
        if request.user.role != "CEO":
            return Response(
                {"detail": "Access denied. CEO role required."}, 
                status=status.HTTP_403_FORBIDDEN
            )
        
        # Get requests where CEO is the current approver
        reimbursements_pending = Reimbursement.objects.filter(
            current_approver_id=request.user.employee_id,
            status__in=["Pending", "Pending Finance"]
        ).select_related('employee')
        
        advances_pending = AdvanceRequest.objects.filter(
            current_approver_id=request.user.employee_id,
            status__in=["Pending", "Pending Finance"]
        ).select_related('employee')

        # Format pending reimbursements
        pending_reimbursements_data = []
        for reimbursement in reimbursements_pending:
            pending_reimbursements_data.append({
                "id": reimbursement.id,
                "employee_id": reimbursement.employee.employee_id,
                "employee_name": reimbursement.employee.fullName,
                "employee_avatar": request.build_absolute_uri(reimbursement.employee.avatar.url) if reimbursement.employee.avatar else None,
                "date": reimbursement.date,
                "amount": float(reimbursement.amount),
                "description": reimbursement.description,
                "payments": reimbursement.payments if reimbursement.payments else [],
                "status": reimbursement.status,
                "rejection_reason": reimbursement.rejection_reason,
                "request_type": "reimbursement"
            })

        # Format pending advances
        pending_advances_data = []
        for advance in advances_pending:
            pending_advances_data.append({
                "id": advance.id,
                "employee_id": advance.employee.employee_id,
                "employee_name": advance.employee.fullName,
                "employee_avatar": request.build_absolute_uri(advance.employee.avatar.url) if advance.employee.avatar else None,
                "date": advance.request_date,
                "amount": float(advance.amount),
                "description": advance.description,
                "payments": advance.payments if advance.payments else [],
                "status": advance.status,
                "rejection_reason": advance.rejection_reason,
                "request_type": "advance"
            })

        # Combine all pending requests
        all_pending_requests = pending_reimbursements_data + pending_advances_data

        return Response({
            "reimbursements_to_approve": pending_reimbursements_data,
            "advances_to_approve": pending_advances_data,
            "all_pending_requests": all_pending_requests
        }, status=status.HTTP_200_OK)
    
class CEOAnalyticsView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        if request.user.role != "CEO":
            return Response(
                {"detail": "Access denied. CEO role required."}, 
                status=status.HTTP_403_FORBIDDEN
            )

        # ADD THESE CALCULATIONS:
        today = timezone.now().date()
        month_start = today.replace(day=1)
        last_month_start = (month_start - timedelta(days=1)).replace(day=1)
        
        # Monthly approved requests count and spending
        monthly_approved_reimbursements = Reimbursement.objects.filter(
            date__gte=month_start,
            status='Approved'
        )
        monthly_approved_advances = AdvanceRequest.objects.filter(
            request_date__gte=month_start, 
            status='Approved'
        )

        # NEW: Monthly approved count
        monthly_approved_count = monthly_approved_reimbursements.count() + monthly_approved_advances.count()
        
        # NEW: Monthly approved spending
        monthly_approved_spending = sum(r.amount for r in monthly_approved_reimbursements) + sum(a.amount for a in monthly_approved_advances)

        # Total requests this month (all statuses)
        total_reimbursements_this_month = Reimbursement.objects.filter(date__gte=month_start).count()
        total_advances_this_month = AdvanceRequest.objects.filter(request_date__gte=month_start).count()
        total_requests_this_month = total_reimbursements_this_month + total_advances_this_month

        # Approval rate calculation
        approval_rate = (monthly_approved_count / total_requests_this_month * 100) if total_requests_this_month > 0 else 0

        # Average request amount (all requests this month)
        total_amount_all = sum(r.amount for r in Reimbursement.objects.filter(date__gte=month_start)) + sum(a.amount for a in AdvanceRequest.objects.filter(request_date__gte=month_start))
        average_request_amount = total_amount_all / total_requests_this_month if total_requests_this_month > 0 else 0

        # Last month approved count for growth calculation
        last_month_approved_reimbursements = Reimbursement.objects.filter(
            date__gte=last_month_start,
            date__lt=month_start,
            status='Approved'
        )
        last_month_approved_advances = AdvanceRequest.objects.filter(
            request_date__gte=last_month_start,
            request_date__lt=month_start,
            status='Approved'
        )
        last_month_approved = last_month_approved_reimbursements.count() + last_month_approved_advances.count()
        monthly_growth = ((monthly_approved_count - last_month_approved) / last_month_approved * 100) if last_month_approved > 0 else 0


        # Add these to your existing analytics data
        analytics_data = {
            # ... your existing analytics fields ...
            
            # NEW: Enhanced analytics as requested
            'monthly_approved_count': monthly_approved_count,
            'monthly_spending': float(monthly_approved_spending),
            'approval_rate': float(approval_rate),
            'average_request_amount': float(average_request_amount),
            'total_requests_this_month': total_requests_this_month,
            'monthly_growth': float(monthly_growth),
            # Keep your existing fields
            'reimbursement_count': total_reimbursements_this_month,
            'advance_count': total_advances_this_month,
            'approved_count': monthly_approved_count,
            'rejected_count': Reimbursement.objects.filter(date__gte=month_start, status='Rejected').count() + AdvanceRequest.objects.filter(request_date__gte=month_start, status='Rejected').count(),
            'pending_count': Reimbursement.objects.filter(date__gte=month_start, status='Pending').count() + AdvanceRequest.objects.filter(request_date__gte=month_start, status='Pending').count(),
        
            # ... rest of your existing analytics ...
        }

        return Response(analytics_data, status=status.HTTP_200_OK)
    
class CEOHistoryView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        # Check if user is CEO
        if request.user.role != "CEO":
            return Response(
                {"detail": "Access denied. CEO role required."}, 
                status=status.HTTP_403_FORBIDDEN
            )

        period = request.GET.get('period', 'last_30_days')
        
        # Calculate date range based on period
        end_date = timezone.now().date()
        if period == 'last_7_days':
            start_date = end_date - timedelta(days=7)
        elif period == 'last_90_days':
            start_date = end_date - timedelta(days=90)
        else:  # last_30_days default
            start_date = end_date - timedelta(days=30)

        # NEW: Get ONLY requests where CEO took action (approved/rejected)
        ceo_employee_id = request.user.employee_id
        
        # Get requests where CEO was the final approver/rejector
        reimbursement_history = Reimbursement.objects.filter(
            Q(status__in=['Approved', 'Rejected']) &  # Final decisions only
            Q(final_approver=ceo_employee_id) &  # CEO was involved
            Q(updated_at__range=[start_date, end_date + timedelta(days=1)])
        ).select_related('employee').order_by('-updated_at')
        
        advance_history = AdvanceRequest.objects.filter(
            Q(status__in=['Approved', 'Rejected']) &  # Final decisions only  
            Q(final_approver=ceo_employee_id) &  # CEO was involved
            Q(updated_at__range=[start_date, end_date + timedelta(days=1)])
        ).select_related('employee').order_by('-updated_at')

        # Format CEO-specific history
        history_data = []
        
        for reimbursement in reimbursement_history:
            history_data.append({
                'id': reimbursement.id,
                'employee_id': reimbursement.employee.employee_id,
                'employee_name': reimbursement.employee.fullName,
                'employee_avatar': request.build_absolute_uri(reimbursement.employee.avatar.url) if reimbursement.employee.avatar else None,
                'type': 'reimbursement',
                'amount': float(reimbursement.amount),
                'date': reimbursement.date.strftime('%Y-%m-%d') if reimbursement.date else None,
                'description': reimbursement.description,
                'status': reimbursement.status,
                'ceo_action': 'approved' if reimbursement.status == 'Approved' else 'rejected',
                'rejection_reason': reimbursement.rejection_reason,
                'action_date': reimbursement.updated_at.strftime('%Y-%m-%d %H:%M'),
                'submission_date': reimbursement.created_at.strftime('%Y-%m-%d') if reimbursement.created_at else None
            })

        for advance in advance_history:
            history_data.append({
                'id': advance.id,
                'employee_id': advance.employee.employee_id,
                'employee_name': advance.employee.fullName,
                'employee_avatar': request.build_absolute_uri(advance.employee.avatar.url) if advance.employee.avatar else None,
                'type': 'advance',
                'amount': float(advance.amount),
                'date': advance.request_date.strftime('%Y-%m-%d') if advance.request_date else None,
                'description': advance.description,
                'status': advance.status,
                'ceo_action': 'approved' if advance.status == 'Approved' else 'rejected',
                'rejection_reason': advance.rejection_reason,
                'action_date': advance.updated_at.strftime('%Y-%m-%d %H:%M'),
                'submission_date': advance.created_at.strftime('%Y-%m-%d') if advance.created_at else None
            })

        # Sort by action date (most recent first)
        history_data.sort(key=lambda x: x['action_date'], reverse=True)

        return Response({
            'history': history_data,
            'period': period,
            'total_count': len(history_data),
            'start_date': start_date.strftime('%Y-%m-%d'),
            'end_date': end_date.strftime('%Y-%m-%d')
        }, status=status.HTTP_200_OK)
    
class CEOApproveRequestView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        # Check if user is CEO
        if request.user.role != "CEO":
            return Response(
                {"detail": "Access denied. CEO role required."}, 
                status=status.HTTP_403_FORBIDDEN
            )
        
        request_id = request.data.get('request_id')
        request_type = request.data.get('request_type')
        
        if not request_id or not request_type:
            return Response(
                {'error': 'request_id and request_type are required'},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            if request_type == 'reimbursement':
                reimbursement = Reimbursement.objects.get(id=request_id)
                # Check if CEO is the current approver
                if reimbursement.current_approver_id != request.user.employee_id:
                    return Response(
                        {'error': 'Not authorized to approve this request'},
                        status=status.HTTP_403_FORBIDDEN
                    )
                # Process CEO approval
                process_approval(reimbursement, request.user, approved=True)
                return Response({
                  'message': 'Reimbursement approved by CEO successfully',
                   'status': reimbursement.status  # ✅ "Approved" return hoga
                  })
                
            elif request_type == 'advance':
                advance = AdvanceRequest.objects.get(id=request_id)
                # Check if CEO is the current approver
                if advance.current_approver_id != request.user.employee_id:
                    return Response(
                        {'error': 'Not authorized to approve this request'},
                        status=status.HTTP_403_FORBIDDEN
                    )
                # Process CEO approval
                process_approval(advance, request.user, approved=True)
                
                return Response({
                    'message': 'Advance approved by CEO successfully',
                    'status': advance.status
                })
                
            else:
                return Response(
                    {'error': 'Invalid request type'},
                    status=status.HTTP_400_BAD_REQUEST
                )
                
        except (Reimbursement.DoesNotExist, AdvanceRequest.DoesNotExist):
            return Response(
                {'error': 'Request not found'},
                status=status.HTTP_404_NOT_FOUND
            )


class CEORejectRequestView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        # Check if user is CEO
        if request.user.role != "CEO":
            return Response(
                {"detail": "Access denied. CEO role required."}, 
                status=status.HTTP_403_FORBIDDEN
            )
        
        request_id = request.data.get('request_id')
        request_type = request.data.get('request_type')
        reason = request.data.get('reason', '')
        
        if not request_id or not request_type:
            return Response(
                {'error': 'request_id and request_type are required'},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            if request_type == 'reimbursement':
                reimbursement = Reimbursement.objects.get(id=request_id)
                # Check if CEO is the current approver
                if reimbursement.current_approver_id != request.user.employee_id:
                    return Response(
                        {'error': 'Not authorized to reject this request'},
                        status=status.HTTP_403_FORBIDDEN
                    )
                # Process CEO rejection
                process_approval(reimbursement, request.user, approved=False, rejection_reason=reason)
                
                return Response({
                    'message': 'Reimbursement rejected by CEO',
                    'status': reimbursement.status
                })
                
            elif request_type == 'advance':
                advance = AdvanceRequest.objects.get(id=request_id)
                # Check if CEO is the current approver
                if advance.current_approver_id != request.user.employee_id:
                    return Response(
                        {'error': 'Not authorized to reject this request'},
                        status=status.HTTP_403_FORBIDDEN
                    )
                # Process CEO rejection
                process_approval(advance, request.user, approved=False, rejection_reason=reason)
                
                return Response({
                    'message': 'Advance rejected by CEO',
                    'status': advance.status
                })
                
            else:
                return Response(
                    {'error': 'Invalid request type'},
                    status=status.HTTP_400_BAD_REQUEST
                )
                
        except (Reimbursement.DoesNotExist, AdvanceRequest.DoesNotExist):
            return Response(
                {'error': 'Request not found'},
                status=status.HTTP_404_NOT_FOUND
            )


class CEORequestDetailsView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, request_id):
        # Check if user is CEO
        if request.user.role != "CEO":
            return Response(
                {"detail": "Access denied. CEO role required."}, 
                status=status.HTTP_403_FORBIDDEN
            )
        
        request_type = request.GET.get('request_type')
        
        if not request_type:
            return Response(
                {'error': 'request_type parameter is required'},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            if request_type == 'reimbursement':
                reimbursement = Reimbursement.objects.get(id=request_id)
                data = {
                    'id': reimbursement.id,
                    'employee_id': reimbursement.employee.employee_id,
                    'employee_name': reimbursement.employee.fullName,
                    'employee_avatar': request.build_absolute_uri(reimbursement.employee.avatar.url) if reimbursement.employee.avatar else None,
                    'employee_department': reimbursement.employee.department,
                    'employee_email': reimbursement.employee.email,
                    'date': reimbursement.date,
                    'amount': float(reimbursement.amount),
                    'description': reimbursement.description,
                    'payments': reimbursement.payments if reimbursement.payments else [],
                    'status': reimbursement.status,
                    'rejection_reason': reimbursement.rejection_reason,
                    'created_at': reimbursement.created_at,
                    'updated_at': reimbursement.updated_at,
                    'request_type': 'reimbursement'
                }
                return Response(data)
                
            elif request_type == 'advance':
                advance = AdvanceRequest.objects.get(id=request_id)
                data = {
                    'id': advance.id,
                    'employee_id': advance.employee.employee_id,
                    'employee_name': advance.employee.fullName,
                    'employee_avatar': request.build_absolute_uri(advance.employee.avatar.url) if advance.employee.avatar else None,
                    'employee_department': advance.employee.department,
                    'employee_email': advance.employee.email,
                    'request_date': advance.request_date,
                    'project_date': advance.project_date,
                    'amount': float(advance.amount),
                    'description': advance.description,
                    'payments': advance.payments if advance.payments else [],
                    'status': advance.status,
                    'rejection_reason': advance.rejection_reason,
                    'created_at': advance.created_at,
                    'updated_at': advance.updated_at,
                    'request_type': 'advance'
                }
                return Response(data)
                
            else:
                return Response(
                    {'error': 'Invalid request type'},
                    status=status.HTTP_400_BAD_REQUEST
                )
                
        except (Reimbursement.DoesNotExist, AdvanceRequest.DoesNotExist):
            return Response(
                {'error': 'Request not found'},
                status=status.HTTP_404_NOT_FOUND
            )
        
class CEOGenerateReportView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        # Check if user is CEO
        if request.user.role != "CEO":
            return Response(
                {"detail": "Access denied. CEO role required."}, 
                status=status.HTTP_403_FORBIDDEN
            )

        report_type = request.GET.get('report_type', 'monthly')
        months = int(request.GET.get('months', 1))
        
        # Calculate date range
        end_date = timezone.now().date()
        start_date = end_date - timedelta(days=30*months)
        
        # Get data based on report type
        if report_type == 'monthly':
            reimbursements = Reimbursement.objects.filter(
                date__range=[start_date, end_date]
            ).select_related('employee')
            
            advances = AdvanceRequest.objects.filter(
                request_date__range=[start_date, end_date]
            ).select_related('employee')
        elif report_type == 'approved':
            reimbursements = Reimbursement.objects.filter(
                date__range=[start_date, end_date],
                status='Approved'
            ).select_related('employee')
            
            advances = AdvanceRequest.objects.filter(
                request_date__range=[start_date, end_date],
                status='Approved'
            ).select_related('employee')
        else:  # all data
            reimbursements = Reimbursement.objects.filter(
                date__range=[start_date, end_date]
            ).select_related('employee')
            
            advances = AdvanceRequest.objects.filter(
                request_date__range=[start_date, end_date]
            ).select_related('employee')

        # Create CSV response
        response = HttpResponse(content_type='text/csv')
        response['Content-Disposition'] = f'attachment; filename="ceo_report_{report_type}_{months}months.csv"'
        
        writer = csv.writer(response)
        # Enhanced CSV headers
        writer.writerow([
            'Request ID', 'Employee ID', 'Employee Name', 'Department',
            'Request Type', 'Amount', 'Submission Date', 'Status',
            'CEO Action', 'Rejection Reason', 'Description', 'Payment Count'
        ])
        
        # Write reimbursement data
        for reimbursement in reimbursements:
            payment_count = len(reimbursement.payments) if reimbursement.payments else 0
            writer.writerow([
                reimbursement.id,
                reimbursement.employee.employee_id,
                reimbursement.employee.fullName,
                reimbursement.employee.department,
                'Reimbursement',
                reimbursement.amount,
                reimbursement.date,
                reimbursement.status,
                'Approved' if reimbursement.status == 'Approved' else 'Rejected' if reimbursement.status == 'Rejected' else 'Pending',
                reimbursement.rejection_reason or '',
                reimbursement.description,
                payment_count
            ])
        
        # Write advance data
        for advance in advances:
            payment_count = len(advance.payments) if advance.payments else 0
            writer.writerow([
                advance.id,
                advance.employee.employee_id,
                advance.employee.fullName,
                advance.employee.department,
                'Advance',
                advance.amount,
                advance.request_date,
                advance.status,
                'Approved' if advance.status == 'Approved' else 'Rejected' if advance.status == 'Rejected' else 'Pending',
                advance.rejection_reason or '',
                advance.description,
                payment_count
            ])
        
        return response