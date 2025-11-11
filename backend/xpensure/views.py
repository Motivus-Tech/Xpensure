from rest_framework import status, permissions, generics, viewsets
from rest_framework.response import Response
from rest_framework.views import APIView
from .models import Employee, Reimbursement, AdvanceRequest, ApprovalHistory
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
# Reimbursement ViewSet - FIXED
# -----------------------------
class ReimbursementViewSet(viewsets.ModelViewSet):
    serializer_class = ReimbursementSerializer
    permission_classes = [permissions.IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]

    def get_queryset(self):
        return Reimbursement.objects.filter(employee=self.request.user).order_by('-date')
    
    def create(self, request, *args, **kwargs):
        # ✅ ADD DEBUG LOGGING
        print("=== REIMBURSEMENT SUBMISSION DATA ===")
        print("Request data:", dict(request.data))
        print("Project ID from request:", request.data.get('project_id'))
        print("Files:", request.FILES)
        
        return super().create(request, *args, **kwargs)
    
    def perform_create(self, serializer):
        employee = self.request.user
        next_approver = employee.report_to if employee.report_to else None
        status = "Pending" if next_approver else "Approved"
        
        # ✅ ADD DEBUG LOGGING FOR PROJECT ID
        project_id = self.request.data.get('project_id')
        print(f"Reimbursement Project ID: {project_id}")
        
        # ✅ FIXED: Only call save() once with all parameters
        instance = serializer.save(
            employee=employee, 
            current_approver_id=next_approver, 
            status=status,
            project_id=project_id  # ✅ EXPLICITLY SAVE PROJECT ID
        )
        
        # ✅ CREATE INITIAL SUBMISSION HISTORY
        ApprovalHistory.objects.create(
            request_type='reimbursement',
            request_id=instance.id,
            approver_id=employee.employee_id,
            approver_name=employee.fullName,
            action='submitted',
            comments='Request submitted'
        )
        
        # If no approver (auto-approved), create approval history
        if not next_approver:
            ApprovalHistory.objects.create(
                request_type='reimbursement',
                request_id=instance.id,
                approver_id='system',
                approver_name='System',
                action='approved',
                comments='Auto-approved (no approver chain)'
            )

# -----------------------------
# Advance Request ViewSet - FIXED
# -----------------------------
class AdvanceRequestViewSet(viewsets.ModelViewSet):
    serializer_class = AdvanceRequestSerializer
    permission_classes = [permissions.IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]

    def get_queryset(self):
        return AdvanceRequest.objects.filter(employee=self.request.user).order_by('-request_date')
    
    def create(self, request, *args, **kwargs):
        # ✅ ADD DEBUG LOGGING
        print("=== ADVANCE SUBMISSION DATA ===")
        print("Request data:", dict(request.data))
        print("Project ID from request:", request.data.get('project_id'))
        print("Project Name from request:", request.data.get('project_name'))
        print("Files:", request.FILES)
        
        return super().create(request, *args, **kwargs)

    def perform_create(self, serializer):
        employee = self.request.user
        next_approver = employee.report_to if employee.report_to else None
        status = "Pending" if next_approver else "Approved"
        
        # ✅ ADD DEBUG LOGGING FOR PROJECT DATA
        project_id = self.request.data.get('project_id')
        project_name = self.request.data.get('project_name')
        print(f"Advance Project ID: {project_id}, Project Name: {project_name}")
        
        # ✅ FIXED: Only call save() once with all parameters
        instance = serializer.save(
            employee=employee, 
            current_approver_id=next_approver, 
            status=status,
            project_id=project_id,  # ✅ EXPLICITLY SAVE PROJECT ID
            project_name=project_name  # ✅ EXPLICITLY SAVE PROJECT NAME
        )
        
        # ✅ CREATE INITIAL SUBMISSION HISTORY
        ApprovalHistory.objects.create(
            request_type='advance',
            request_id=instance.id,
            approver_id=employee.employee_id,
            approver_name=employee.fullName,
            action='submitted',
            comments='Request submitted'
        )
        
        # If no approver (auto-approved), create approval history
        if not next_approver:
            ApprovalHistory.objects.create(
                request_type='advance',
                request_id=instance.id,
                approver_id='system',
                approver_name='System',
                action='approved',
                comments='Auto-approved (no approver chain)'
            )
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
# CSV Download for Employee Dashboard
# -----------------------------
class EmployeeCSVDownloadView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        try:
            period = request.GET.get('period', '1 Month')
            employee_id = request.user.employee_id
            
            # Calculate date range based on period
            end_date = timezone.now().date()
            if period == "1 Month":
                start_date = end_date - timedelta(days=30)
            elif period == "3 Months":
                start_date = end_date - timedelta(days=90)
            elif period == "6 Months":
                start_date = end_date - timedelta(days=180)
            elif period == "1 Year":
                start_date = end_date - timedelta(days=365)
            else:
                start_date = end_date - timedelta(days=30)

            # Get employee's requests within date range
            reimbursements = Reimbursement.objects.filter(
                employee_id=employee_id,
                created_at__date__range=[start_date, end_date]
            ).order_by('-created_at')

            advances = AdvanceRequest.objects.filter(
                employee_id=employee_id,
                created_at__date__range=[start_date, end_date]
            ).order_by('-created_at')

            # Create CSV response
            response = HttpResponse(content_type='text/csv')
            response['Content-Disposition'] = f'attachment; filename="xpensure_requests_{period.replace(" ", "_").lower()}_{end_date}.csv"'
            
            writer = csv.writer(response)
            # Write header
            writer.writerow([
                'S.No', 'Request Type', 'Amount', 'Status', 
                'Submission Date', 'Description', 'Payment Date'
            ])
            
            # Write reimbursement data
            for i, reimbursement in enumerate(reimbursements, 1):
                writer.writerow([
                    i,
                    'Reimbursement',
                    f'₹{reimbursement.amount}',
                    reimbursement.status,
                    reimbursement.created_at.strftime('%Y-%m-%d') if reimbursement.created_at else '-',
                    reimbursement.description or 'No description',
                    reimbursement.payment_date.strftime('%Y-%m-%d') if reimbursement.payment_date else '-'
                ])
            
            # Write advance data
            for i, advance in enumerate(advances, len(reimbursements) + 1):
                writer.writerow([
                    i,
                    'Advance',
                    f'₹{advance.amount}',
                    advance.status,
                    advance.created_at.strftime('%Y-%m-%d') if advance.created_at else '-',
                    advance.description or 'No description',
                    advance.payment_date.strftime('%Y-%m-%d') if advance.payment_date else '-'
                ])
            
            return response
            
        except Exception as e:
            return Response(
                {'error': f'Failed to generate CSV: {str(e)}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
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


def get_next_approver(employee):
    """
    FIXED: Returns the next approver based on report_to hierarchy.
    """
    if not employee or not employee.report_to:
        return None
    
    try:
        next_approver = User.objects.get(employee_id=employee.report_to)
        print(f"🔗 Next approver for {employee.employee_id}: {next_approver.employee_id} ({next_approver.role})")
        return next_approver.employee_id
    except User.DoesNotExist:
        print(f"❌ Next approver {employee.report_to} not found for {employee.employee_id}")
        return None
    
def process_approval(request_obj, approver_employee, approved=True, rejection_reason=None):
    """
    FIXED VERSION: CEO approve -> Status=Approved, Finance Payment -> Status=Paid
    """
    request_type = 'reimbursement' if hasattr(request_obj, 'date') else 'advance'
    
    if not approved:
        # REJECTION
        request_obj.status = "Rejected"
        request_obj.rejection_reason = rejection_reason
        request_obj.current_approver_id = None
        request_obj.final_approver = approver_employee.employee_id
        
        ApprovalHistory.objects.create(
            request_type=request_type,
            request_id=request_obj.id,
            approver_id=approver_employee.employee_id,
            approver_name=approver_employee.fullName,
            action='rejected',
            comments=rejection_reason or 'Request rejected'
        )
        
        request_obj.save()
        return request_obj

    # ✅ CREATE APPROVAL HISTORY FOR CURRENT APPROVER
    ApprovalHistory.objects.create(
        request_type=request_type,
        request_id=request_obj.id,
        approver_id=approver_employee.employee_id,
        approver_name=approver_employee.fullName,
        action='approved',
        comments=f'Approved by {approver_employee.role} ({approver_employee.fullName})'
    )

    # ✅ FIXED: CEO APPROVAL = FINAL APPROVAL (Status=Approved)
    if approver_employee.role == "CEO":
        request_obj.status = "Approved"
        request_obj.current_approver_id = None
        request_obj.final_approver = approver_employee.employee_id
        request_obj.currentStep = 6
        request_obj.approved_by_ceo = True  # ✅ IMPORTANT: Set this flag
        print(f"✅ CEO Final Approval: Request {request_obj.id} approved by CEO")
        
        # ✅ AUTO-ASSIGN TO FINANCE PAYMENT FOR PROCESSING
        finance_payment_users = User.objects.filter(role="Finance Payment")
        if finance_payment_users.exists():
            next_approver = finance_payment_users.first()
            request_obj.current_approver_id = next_approver.employee_id
            print(f"💰 Sent to Finance Payment for payment processing: {next_approver.employee_id}")

    # ✅ FINANCE PAYMENT = MARK AS PAID
    elif approver_employee.role == "Finance Payment":
        request_obj.status = "Paid"
        request_obj.current_approver_id = None
        request_obj.payment_date = timezone.now()
        request_obj.currentStep = 7
        print(f"💰 Payment Processed: Request {request_obj.id} marked as paid by Finance Payment")

    # ✅ OTHER ROLES (Common, Finance Verification) - NORMAL CHAIN FLOW
    else:
        next_approver_id = get_next_approver(approver_employee)
        
        if next_approver_id:
            request_obj.current_approver_id = next_approver_id
            request_obj.status = "Pending"
            
            # Track steps based on next approver's role
            try:
                next_approver = User.objects.get(employee_id=next_approver_id)
                if next_approver.role == "Finance Verification":
                    request_obj.currentStep = 3
                    request_obj.approved_by_finance = False
                elif next_approver.role == "CEO":
                    request_obj.currentStep = 4
                elif next_approver.role == "Finance Payment":
                    request_obj.currentStep = 5
                else:
                    request_obj.currentStep = 2
                    
                print(f"✅ {approver_employee.role} → {next_approver.role}: Request {request_obj.id} sent to {next_approver_id}")
            except User.DoesNotExist:
                print(f"❌ Next approver {next_approver_id} not found")
        else:
            # No next approver - final approval (for non-CEO roles)
            request_obj.status = "Approved"
            request_obj.current_approver_id = None
            request_obj.final_approver = approver_employee.employee_id
            request_obj.currentStep = 6
            print(f"✅ Final approval by {approver_employee.role}")

    request_obj.save()
    return request_obj
# ----------------------------
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
                    "rejection_reason": r.rejection_reason,  # ✅ ADDED COMMA
                    "projectId": r.project_id,  # ✅ ADDED COMMA
                    "project_id": r.project_id,
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
                    "rejection_reason": a.rejection_reason,  # ✅ ADDED COMMA
                    # ✅ ADD PROJECT FIELDS
                    "projectId": a.project_id,
                    "project_id": a.project_id,
                    "projectName": a.project_name,
                    "project_name": a.project_name,
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
                    "payment_date": r.payment_date,  # ✅ ADDED COMMA
                    # ✅ ADD PROJECT FIELDS - THIS IS WHAT'S MISSING!
                    "projectId": r.project_id,
                    "project_id": r.project_id,
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
                    "payment_date": a.payment_date,  # ✅ ADDED COMMA
                     # ✅ ADD PROJECT FIELDS - THIS IS WHAT'S MISSING!
                    "projectId": a.project_id,
                    "project_id": a.project_id,
                    "projectName": a.project_name,
                    "project_name": a.project_name,
                }
                for a in advances_created
            ],
        }
        
        return Response(data, status=status.HTTP_200_OK)
    
def health_check(request):
    return JsonResponse({"status": "ok"})

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
        
        ceo_employee_id = request.user.employee_id
        
        print(f"🔍 CEO Dashboard - CEO ID: {ceo_employee_id}")
        
        # Get requests where CEO is the current approver
        reimbursements_pending = Reimbursement.objects.filter(
            current_approver_id=ceo_employee_id,
            status="Pending"
        ).select_related('employee')
        
        advances_pending = AdvanceRequest.objects.filter(
            current_approver_id=ceo_employee_id,
            status="Pending"
        ).select_related('employee')

        # Also get requests that are approved by finance and should go to CEO
        reimbursements_from_finance = Reimbursement.objects.filter(
            approved_by_finance=True,
            status="Pending"
        ).select_related('employee')
        
        advances_from_finance = AdvanceRequest.objects.filter(
            approved_by_finance=True, 
            status="Pending"
        ).select_related('employee')

        # Combine all CEO pending requests
        all_reimbursements = list(reimbursements_pending) + list(reimbursements_from_finance)
        all_advances = list(advances_pending) + list(advances_from_finance)

        # Remove duplicates
        all_reimbursements = list({r.id: r for r in all_reimbursements}.values())
        all_advances = list({a.id: a for a in all_advances}.values())

        print(f"📊 CEO Dashboard - Reimbursements: {len(all_reimbursements)}, Advances: {len(all_advances)}")

        # Format pending reimbursements - ✅ CRITICAL FIX: ADD PROJECT FIELDS
        pending_reimbursements_data = []
        for reimbursement in all_reimbursements:
            print(f"🔍 Reimbursement {reimbursement.id} - Project ID: {reimbursement.project_id}")
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
                "request_type": "reimbursement",
                "approved_by_finance": reimbursement.approved_by_finance,
                "current_approver_id": reimbursement.current_approver_id,
                # ✅ CRITICAL: ADD PROJECT INFORMATION FOR REIMBURSEMENTS
                "project_id": reimbursement.project_id,  # This was missing!
                "project_code": reimbursement.project_id,  # Using project_id as project_code
                "project_name": None,  # Reimbursements typically don't have project_name
            })

        # Format pending advances - ✅ CRITICAL FIX: ADD PROJECT FIELDS
        pending_advances_data = []
        for advance in all_advances:
            print(f"🔍 Advance {advance.id} - Project ID: {advance.project_id}, Project Name: {advance.project_name}")
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
                "request_type": "advance",
                "approved_by_finance": advance.approved_by_finance,
                "current_approver_id": advance.current_approver_id,
                # ✅ CRITICAL: ADD PROJECT INFORMATION FOR ADVANCES
                "project_id": advance.project_id,  # This was missing!
                "project_code": advance.project_id,
                "project_name": advance.project_name,  # This was missing!
                "project_title": advance.project_name,  # Alternative key
            })

        # Combine all pending requests
        all_pending_requests = pending_reimbursements_data + pending_advances_data

        return Response({
            "reimbursements_to_approve": pending_reimbursements_data,
            "advances_to_approve": pending_advances_data,
            "all_pending_requests": all_pending_requests,
            "debug_info": {
                "ceo_employee_id": ceo_employee_id,
                "reimbursements_count": len(pending_reimbursements_data),
                "advances_count": len(pending_advances_data)
            }
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
                # ✅ FIXED: Check multiple authorization conditions
                is_authorized = (
                    reimbursement.current_approver_id == request.user.employee_id or
                    reimbursement.approved_by_finance == True or
                    reimbursement.status == "Pending"  # General pending status check
                )
                
                if not is_authorized:
                    return Response(
                        {'error': 'Not authorized to approve this request'},
                        status=status.HTTP_403_FORBIDDEN
                    )
                
                # Process CEO approval
                process_approval(reimbursement, request.user, approved=True)
                return Response({
                    'message': 'Reimbursement approved by CEO successfully',
                    'status': reimbursement.status
                })
                
            elif request_type == 'advance':
                advance = AdvanceRequest.objects.get(id=request_id)
                # ✅ FIXED: Check multiple authorization conditions
                is_authorized = (
                    advance.current_approver_id == request.user.employee_id or
                    advance.approved_by_finance == True or
                    advance.status == "Pending"  # General pending status check
                )
                
                if not is_authorized:
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
                # ✅ FIXED: Use same multiple authorization conditions as approval
                is_authorized = (
                    reimbursement.current_approver_id == request.user.employee_id or
                    reimbursement.approved_by_finance == True or
                    reimbursement.status == "Pending"  # General pending status check
                )
                
                if not is_authorized:
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
                # ✅ FIXED: Use same multiple authorization conditions as approval
                is_authorized = (
                    advance.current_approver_id == request.user.employee_id or
                    advance.approved_by_finance == True or
                    advance.status == "Pending"  # General pending status check
                )
                
                if not is_authorized:
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
            'CEO Action', 'Rejection Reason', 'Description', 'Payment Count',
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
    
class ApprovalTimelineView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, request_id):
        request_type = request.GET.get('request_type')
        
        if not request_type:
            return Response(
                {'error': 'request_type parameter is required'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Get approval history
        approval_history = ApprovalHistory.objects.filter(
            request_type=request_type,
            request_id=request_id
        ).order_by('timestamp')

        # Get request details
        if request_type == 'reimbursement':
            request_obj = Reimbursement.objects.filter(id=request_id).first()
        else:
            request_obj = AdvanceRequest.objects.filter(id=request_id).first()

        if not request_obj:
            return Response(
                {'error': 'Request not found'},
                status=status.HTTP_404_NOT_FOUND
            )

        # ✅ FIXED: Build proper stepper flow
        timeline = self._build_proper_stepper_flow(request_obj, approval_history)
        
        return Response({
            'timeline': timeline,
            'current_status': request_obj.status,
            'current_step': self._get_current_step(timeline, request_obj.status),
            'is_rejected': request_obj.status == 'Rejected'
        })

    def _build_proper_stepper_flow(self, request_obj, approval_history):
        """Build proper stepper flow with clear steps - FIXED VERSION"""
        timeline = []
        
        # Step 1: Request Submitted
        timeline.append({
            'step': 'Request Submitted',
            'approver_name': request_obj.employee.fullName,
            'approver_id': request_obj.employee.employee_id,
            'timestamp': request_obj.created_at,
            'status': 'completed',
            'action': 'submitted',
            'step_type': 'submission',
            'comments': 'Request submitted by employee'
        })

        # ✅ FIXED: Add ALL approval steps from history
        for history in approval_history:
            if history.action == 'approved':
                timeline.append({
                    'step': f'Approved by {history.approver_name}',
                    'approver_name': history.approver_name,
                    'approver_id': history.approver_id,
                    'timestamp': history.timestamp,
                    'status': 'completed',
                    'action': 'approved',
                    'step_type': self._get_step_type(history.approver_id),
                    'comments': history.comments
                })
            elif history.action == 'forwarded':
                timeline.append({
                    'step': f'Forwarded by {history.approver_name}',
                    'approver_name': history.approver_name,
                    'approver_id': history.approver_id,
                    'timestamp': history.timestamp,
                    'status': 'completed',
                    'action': 'forwarded',
                    'step_type': self._get_step_type(history.approver_id),
                    'comments': history.comments
                })
            elif history.action == 'rejected':
                timeline.append({
                    'step': f'Rejected by {history.approver_name}',
                    'approver_name': history.approver_name,
                    'approver_id': history.approver_id,
                    'timestamp': history.timestamp,
                    'status': 'rejected',
                    'action': 'rejected',
                    'step_type': self._get_step_type(history.approver_id),
                    'comments': history.comments
                })

        # ✅ FIXED: Check for CEO approval and add Finance Payment step
        if request_obj.status == 'Approved' and request_obj.approved_by_ceo:
            # Add Finance Payment step
            timeline.append({
                'step': 'Ready for Payment Processing',
                'approver_name': 'Finance Payment',
                'approver_id': 'finance_payment',
                'timestamp': None,
                'status': 'pending' if request_obj.status == 'Approved' else 'completed',
                'action': 'pending',
                'step_type': 'finance_payment',
                'comments': 'Ready for payment processing by Finance Team'
            })

        # ✅ FIXED: Add Payment Processed Step if paid
        if request_obj.status == 'Paid':
            # Remove the pending payment step if exists and add completed one
            timeline = [t for t in timeline if not (t['step_type'] == 'finance_payment' and t['status'] == 'pending')]
            
            timeline.append({
                'step': 'Payment Processed',
                'approver_name': 'Finance Payment',
                'approver_id': 'finance_payment',
                'timestamp': request_obj.payment_date,
                'status': 'paid',
                'action': 'paid',
                'step_type': 'finance_payment',
                'comments': 'Payment has been processed successfully'
            })

        return timeline

    def _get_step_type(self, approver_id):
        """Determine step type based on approver role"""
        try:
            approver = User.objects.get(employee_id=approver_id)
            return approver.role.lower().replace(' ', '_')
        except User.DoesNotExist:
            if approver_id == 'system':
                return 'system'
            return 'unknown'

    def _get_current_step(self, timeline, status):
        """Get current active step number"""
        if status == 'Rejected':
            return len([t for t in timeline if t['status'] in ['completed', 'rejected']])
        
        if status == 'Paid':
            return len(timeline)
            
        completed_steps = len([t for t in timeline if t['status'] in ['completed', 'paid']])
        return completed_steps + 1  # +1 for the next pending step

    def _get_step_type(self, approver_id):
        """Determine step type based on approver role"""
        try:
            approver = User.objects.get(employee_id=approver_id)
            return approver.role.lower()
        except User.DoesNotExist:
            return 'system'

    def _get_current_step(self, timeline, status):
        """Get current active step number"""
        if status == 'Rejected':
            return len(timeline)
        
        completed_steps = len([t for t in timeline if t['status'] in ['completed', 'paid']])
        return completed_steps
    

class FinanceVerificationDashboardView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        if request.user.role != "Finance Verification":
            return Response(
                {"detail": "Access denied. Finance Verification role required."}, 
                status=status.HTTP_403_FORBIDDEN
            )
        
        pending_verification = []
        
        # Reimbursements
        reimbursement_pending = Reimbursement.objects.filter(
            current_approver_id=request.user.employee_id,
            status="Pending"
        ).select_related('employee')
        
        for reimbursement in reimbursement_pending:
            # ✅ FIXED: PROPERLY INCLUDE PAYMENTS AND ATTACHMENTS
            request_data = {
                'id': reimbursement.id,
                'employee_id': reimbursement.employee.employee_id,
                'employee_name': reimbursement.employee.fullName,
                'employee_avatar': request.build_absolute_uri(reimbursement.employee.avatar.url) if reimbursement.employee.avatar else None,
                'date': reimbursement.date,
                'amount': float(reimbursement.amount),
                'description': reimbursement.description,
                'payments': reimbursement.payments if reimbursement.payments else [],  # ✅ CRITICAL FIX
                'request_type': 'reimbursement',
                'status': reimbursement.status,
                'project_id': reimbursement.project_id,
                'attachments': reimbursement.attachments if reimbursement.attachments else [],  # ✅ INCLUDE ATTACHMENTS
                'submitted_date': reimbursement.created_at,
                'current_approver_id': reimbursement.current_approver_id,
                'approved_by_finance': reimbursement.approved_by_finance,
            }
            pending_verification.append(request_data)

        # Advances
        advance_pending = AdvanceRequest.objects.filter(
            current_approver_id=request.user.employee_id,
            status="Pending"
        ).select_related('employee')
        
        for advance in advance_pending:
            request_data = {
                'id': advance.id,
                'employee_id': advance.employee.employee_id,
                'employee_name': advance.employee.fullName,
                'employee_avatar': request.build_absolute_uri(advance.employee.avatar.url) if advance.employee.avatar else None,
                'date': advance.request_date,
                'amount': float(advance.amount),
                'description': advance.description,
                'payments': advance.payments if advance.payments else [],  # ✅ CRITICAL FIX
                'request_type': 'advance',
                'status': advance.status,
                'project_id': advance.project_id,
                'project_name': advance.project_name,
                'attachments': advance.attachments if advance.attachments else [],  # ✅ INCLUDE ATTACHMENTS
                'submitted_date': advance.created_at,
                'current_approver_id': advance.current_approver_id,
                'approved_by_finance': advance.approved_by_finance,
            }
            pending_verification.append(request_data)

        return Response({
            'pending_verification': pending_verification,
            'total_pending': len(pending_verification)
        })
    
class FinanceVerificationApproveView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        if request.user.role != "Finance Verification":
            return Response({"detail": "Access denied."}, status=403)
        
        request_id = request.data.get('request_id')
        request_type = request.data.get('request_type')
        
        try:
            if request_type == 'reimbursement':
                obj = Reimbursement.objects.get(id=request_id)
            elif request_type == 'advance':
                obj = AdvanceRequest.objects.get(id=request_id)
            else:
                return Response({"error": "Invalid request type"}, status=400)

            # Check if current user is the approver
            if obj.current_approver_id != request.user.employee_id:
                return Response({"error": "Not authorized"}, status=403)

            # ✅ USE THE UPDATED process_approval FUNCTION
            process_approval(obj, request.user, approved=True)

            return Response({
                "message": "Request verified and sent to CEO",
                "status": "success"
            })
            
        except (Reimbursement.DoesNotExist, AdvanceRequest.DoesNotExist):
            return Response({"error": "Request not found"}, status=404)
class FinanceVerificationRejectView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        if request.user.role != "Finance Verification":
            return Response({"detail": "Access denied."}, status=403)
        
        request_id = request.data.get('request_id')
        request_type = request.data.get('request_type')
        reason = request.data.get('reason', '')
        
        try:
            if request_type == 'reimbursement':
                obj = Reimbursement.objects.get(id=request_id)
            elif request_type == 'advance':
                obj = AdvanceRequest.objects.get(id=request_id)
            else:
                return Response({"error": "Invalid request type"}, status=400)

            if obj.current_approver_id != request.user.employee_id:
                return Response({"error": "Not authorized"}, status=403)

            # Reject the request
            obj.status = "Rejected"
            obj.rejection_reason = reason
            obj.current_approver_id = None
            obj.save()

            ApprovalHistory.objects.create(
                request_type=request_type,
                request_id=obj.id,
                approver_id=request.user.employee_id,
                approver_name=request.user.fullName,
                action='rejected',
                comments=reason
            )

            return Response({"message": "Request rejected"})
            
        except (Reimbursement.DoesNotExist, AdvanceRequest.DoesNotExist):
            return Response({"error": "Request not found"}, status=404)
class FinancePaymentDashboardView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        if request.user.role != "Finance Payment":
            return Response(
                {"detail": "Access denied. Finance Payment role required."}, 
                status=status.HTTP_403_FORBIDDEN
            )
        
        # ✅ FIXED: Get CEO approved requests that need payment processing WITH ATTACHMENTS
        ready_for_payment = []
        
        # CEO approved reimbursements that need payment (status=Approved)
        reimbursement_ready = Reimbursement.objects.filter(
            Q(current_approver_id=request.user.employee_id) |  # Either assigned to Finance Payment
            Q(status="Approved", approved_by_ceo=True)  # OR CEO approved but not yet paid
        ).exclude(status="Paid").exclude(status="Rejected").select_related('employee')
        
        for reimbursement in reimbursement_ready:
            # ✅ FIXED: EXTRACT ATTACHMENTS FROM PAYMENTS
            attachments = self._extract_attachments_from_payments(reimbursement.payments)
            
            ready_for_payment.append({
                'id': reimbursement.id,
                'employee_id': reimbursement.employee.employee_id,
                'employee_name': reimbursement.employee.fullName,
                'employee_avatar': request.build_absolute_uri(reimbursement.employee.avatar.url) if reimbursement.employee.avatar else None,
                'date': reimbursement.date,
                'amount': float(reimbursement.amount),
                'description': reimbursement.description,
                'request_type': 'reimbursement',
                'status': reimbursement.status,
                'project_id': reimbursement.project_id,
                'approved_date': reimbursement.updated_at,
                'current_approver': reimbursement.current_approver_id,
                # ✅ CRITICAL: INCLUDE ATTACHMENTS
                'attachments': attachments,
                'payments': reimbursement.payments if reimbursement.payments else [],
            })

        # CEO approved advances that need payment (status=Approved)
        advance_ready = AdvanceRequest.objects.filter(
            Q(current_approver_id=request.user.employee_id) |  # Either assigned to Finance Payment
            Q(status="Approved", approved_by_ceo=True)  # OR CEO approved but not yet paid
        ).exclude(status="Paid").exclude(status="Rejected").select_related('employee')
        
        for advance in advance_ready:
            # ✅ FIXED: EXTRACT ATTACHMENTS FROM PAYMENTS
            attachments = self._extract_attachments_from_payments(advance.payments)
            
            ready_for_payment.append({
                'id': advance.id,
                'employee_id': advance.employee.employee_id,
                'employee_name': advance.employee.fullName,
                'employee_avatar': request.build_absolute_uri(advance.employee.avatar.url) if advance.employee.avatar else None,
                'date': advance.request_date,
                'amount': float(advance.amount),
                'description': advance.description,
                'request_type': 'advance',
                'status': advance.status,
                'project_id': advance.project_id,
                'project_name': advance.project_name,
                'approved_date': advance.updated_at,
                'current_approver': advance.current_approver_id,
                # ✅ CRITICAL: INCLUDE ATTACHMENTS
                'attachments': attachments,
                'payments': advance.payments if advance.payments else [],
            })

        # Paid requests history
        paid_requests = []
        reimbursement_paid = Reimbursement.objects.filter(status="Paid").select_related('employee')[:50]
        advance_paid = AdvanceRequest.objects.filter(status="Paid").select_related('employee')[:50]
        
        for req in list(reimbursement_paid) + list(advance_paid):
            # ✅ FIXED: Include attachments for paid requests too
            attachments = self._extract_attachments_from_payments(req.payments)
            
            paid_requests.append({
                'id': req.id,
                'employee_id': req.employee.employee_id,
                'employee_name': req.employee.fullName,
                'amount': float(req.amount),
                'request_type': 'reimbursement' if hasattr(req, 'date') else 'advance',
                'payment_date': req.payment_date,
                # ✅ INCLUDE ATTACHMENTS FOR PAID REQUESTS
                'attachments': attachments,
                'payments': req.payments if req.payments else [],
            })

        return Response({
            'ready_for_payment': ready_for_payment,
            'paid_requests': paid_requests,
            'pending_payment_count': len(ready_for_payment),
            'total_paid_count': len(paid_requests)
        })
    
    def _extract_attachments_from_payments(self, payments_data):
        """
        Extract all attachment paths from payments JSON data
        """
        attachments = []
        
        if not payments_data:
            return attachments
            
        try:
            # Parse payments JSON if it's a string
            if isinstance(payments_data, str):
                payments = json.loads(payments_data)
            else:
                payments = payments_data
                
            # If payments is a list, iterate through each payment
            if isinstance(payments, list):
                for payment in payments:
                    if isinstance(payment, dict):
                        # Check multiple possible attachment fields
                        attachment_fields = [
                            'attachmentPaths', 'attachments', 'attachment', 
                            'file', 'receipt', 'document', 'files'
                        ]
                        
                        for field in attachment_fields:
                            if field in payment and payment[field]:
                                field_data = payment[field]
                                
                                # Handle list of attachments
                                if isinstance(field_data, list):
                                    for item in field_data:
                                        if isinstance(item, str) and item.strip():
                                            attachments.append(item.strip())
                                # Handle single attachment string
                                elif isinstance(field_data, str) and field_data.strip():
                                    # Try to parse as JSON array
                                    try:
                                        parsed_list = json.loads(field_data)
                                        if isinstance(parsed_list, list):
                                            for item in parsed_list:
                                                if isinstance(item, str) and item.strip():
                                                    attachments.append(item.strip())
                                    except json.JSONDecodeError:
                                        # If not JSON, treat as single attachment
                                        attachments.append(field_data.strip())
            
            # Remove duplicates while preserving order
            seen = set()
            unique_attachments = []
            for attachment in attachments:
                if attachment not in seen:
                    seen.add(attachment)
                    unique_attachments.append(attachment)
                    
            return unique_attachments
            
        except Exception as e:
            print(f"Error extracting attachments from payments: {e}")
            return []
# -----------------------------
# Mark as Paid
# -----------------------------
class FinanceMarkAsPaidView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        if request.user.role != "Finance Payment":
            return Response({"detail": "Access denied."}, status=403)
        
        request_id = request.data.get('request_id')
        request_type = request.data.get('request_type')
        
        try:
            if request_type == 'reimbursement':
                obj = Reimbursement.objects.get(id=request_id)
            elif request_type == 'advance':
                obj = AdvanceRequest.objects.get(id=request_id)
            else:
                return Response({"error": "Invalid request type"}, status=400)

            # ✅ FIXED: Only mark as paid if already approved by CEO
            if obj.status != "Approved":
                return Response({
                    "error": "Request must be approved by CEO before marking as paid"
                }, status=400)

            # Mark as paid
            obj.status = "Paid"
            obj.payment_date = timezone.now()
            obj.current_approver_id = None
            obj.save()

            ApprovalHistory.objects.create(
                request_type=request_type,
                request_id=obj.id,
                approver_id=request.user.employee_id,
                approver_name=request.user.fullName,
                action='paid',
                comments='Payment processed by Finance Payment'
            )

            return Response({"message": "Request marked as paid successfully"})
            
        except (Reimbursement.DoesNotExist, AdvanceRequest.DoesNotExist):
            return Response({"error": "Request not found"}, status=404)
        
class FinancePaymentInsightsView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        if request.user.role != "Finance Payment":
            return Response(
                {"detail": "Access denied. Finance Payment role required."}, 
                status=status.HTTP_403_FORBIDDEN
            )
        
        # Calculate insights data
        today = timezone.now().date()
        month_start = today.replace(day=1)
        
        # Ready for payment counts
        reimbursement_ready = Reimbursement.objects.filter(
            Q(current_approver_id=request.user.employee_id) | 
            Q(status="Approved", approved_by_ceo=True)
        ).exclude(status="Paid").exclude(status="Rejected").count()
        
        advance_ready = AdvanceRequest.objects.filter(
            Q(current_approver_id=request.user.employee_id) | 
            Q(status="Approved", approved_by_ceo=True)
        ).exclude(status="Paid").exclude(status="Rejected").count()
        
        total_ready = reimbursement_ready + advance_ready
        
        # Paid requests this month
        reimbursement_paid_monthly = Reimbursement.objects.filter(
            status="Paid",
            payment_date__gte=month_start
        ).count()
        
        advance_paid_monthly = AdvanceRequest.objects.filter(
            status="Paid", 
            payment_date__gte=month_start
        ).count()
        
        total_paid_monthly = reimbursement_paid_monthly + advance_paid_monthly
        
        # Amount calculations
        ready_amount = 0
        paid_amount_monthly = 0
        
        # Calculate ready amounts
        ready_reimbursements = Reimbursement.objects.filter(
            Q(current_approver_id=request.user.employee_id) | 
            Q(status="Approved", approved_by_ceo=True)
        ).exclude(status="Paid").exclude(status="Rejected")
        
        for req in ready_reimbursements:
            ready_amount += float(req.amount)
            
        ready_advances = AdvanceRequest.objects.filter(
            Q(current_approver_id=request.user.employee_id) | 
            Q(status="Approved", approved_by_ceo=True)
        ).exclude(status="Paid").exclude(status="Rejected")
        
        for req in ready_advances:
            ready_amount += float(req.amount)
        
        # Calculate monthly paid amounts
        paid_reimbursements = Reimbursement.objects.filter(
            status="Paid",
            payment_date__gte=month_start
        )
        
        for req in paid_reimbursements:
            paid_amount_monthly += float(req.amount)
            
        paid_advances = AdvanceRequest.objects.filter(
            status="Paid",
            payment_date__gte=month_start
        )
        
        for req in paid_advances:
            paid_amount_monthly += float(req.amount)
        
        insights_data = {
            'total_ready': total_ready,
            'total_paid_monthly': total_paid_monthly,
            'ready_amount': round(ready_amount, 2),
            'paid_amount_monthly': round(paid_amount_monthly, 2),
            'reimbursement_ready': reimbursement_ready,
            'advance_ready': advance_ready,
            'reimbursement_paid_monthly': reimbursement_paid_monthly,
            'advance_paid_monthly': advance_paid_monthly,
        }
        
        return Response(insights_data, status=status.HTTP_200_OK)