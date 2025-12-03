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
def get_next_approver(employee, request_type=None, current_chain=[]):
    """
    SMART ROUTING: Returns next approver based on report_to hierarchy
    Handles MULTIPLE managers in chain until Finance Verification
    """
    if not employee:
        print("❌ No employee provided to get_next_approver")
        return None
    
    print(f"🔍 Getting next approver for: {employee.employee_id} ({employee.role}) - Request Type: {request_type}")
    
    # ✅ PREVENT INFINITE LOOP - Check if we're stuck in a loop
    if employee.employee_id in current_chain:
        print(f"⚠️ Infinite loop detected! Chain: {current_chain}")
        finance_user = User.objects.filter(role="Finance Verification").first()
        if finance_user:
            print(f"🔄 Loop broken, sending to Finance: {finance_user.employee_id}")
            return finance_user.employee_id
        return None
    
    # ✅ ADD CURRENT EMPLOYEE TO CHAIN
    new_chain = current_chain + [employee.employee_id]
    
    # ✅ CRITICAL FIX: Finance Verification Routing
    if employee.role == "Finance Verification":
        print(f"⚠️ Finance Verification - Processing {request_type} request")
        
        if request_type == "reimbursement":
            # ✅ REIMBURSEMENT: Direct CEO ko jao (HR skip)
            print(f"   Processing REIMBURSEMENT - HR should be skipped")
            
            # Check if CEO is report_to
            if employee.report_to:
                try:
                    next_user = User.objects.get(employee_id=employee.report_to)
                    if next_user.role == "HR":
                        print(f"   ⏩ Skipping HR, looking for CEO...")
                        ceo_user = User.objects.filter(role="CEO").first()
                        if ceo_user:
                            print(f"✅ Finance → CEO: Reimbursement sent to CEO: {ceo_user.employee_id}")
                            return ceo_user.employee_id
                    elif next_user.role == "CEO":
                        print(f"✅ Finance → CEO: Reimbursement sent to CEO: {next_user.employee_id}")
                        return next_user.employee_id
                except User.DoesNotExist:
                    pass
            
            # Direct CEO dhoondo
            ceo_user = User.objects.filter(role="CEO").first()
            if ceo_user:
                print(f"✅ Finance → CEO (Direct): Reimbursement sent to CEO: {ceo_user.employee_id}")
                return ceo_user.employee_id
            
            print(f"❌ CEO not found for reimbursement")
            return None
            
        elif request_type == "advance":
            # ✅ ADVANCE: MUST GO TO HR FIRST (CRITICAL FIX)
            print(f"   Processing ADVANCE - MUST go to HR first")
            
            # First, try to find HR user
            hr_user = User.objects.filter(role="HR").first()
            if hr_user:
                print(f"✅ Finance → HR: Advance MUST go to HR first: {hr_user.employee_id}")
                return hr_user.employee_id
            
            print(f"⚠️ HR not found, checking report_to chain...")
            
            # Fallback to report_to chain
            if employee.report_to:
                try:
                    next_user = User.objects.get(employee_id=employee.report_to)
                    print(f"   Next in report_to chain: {next_user.employee_id} ({next_user.role})")
                    
                    # Check if next is CEO
                    if next_user.role == "CEO":
                        print(f"❌ WARNING: Advance going from Finance to CEO directly!")
                        print(f"   Looking for HR again...")
                        # Try to find any HR user
                        hr_users = User.objects.filter(role="HR")
                        if hr_users.exists():
                            hr_user = hr_users.first()
                            print(f"   🔄 Found HR: {hr_user.employee_id} - Sending there instead")
                            return hr_user.employee_id
                    
                    return next_user.employee_id
                except User.DoesNotExist:
                    print(f"❌ Next in report_to chain not found: {employee.report_to}")
            
            print(f"❌ No HR found and no report_to chain for advance")
            return None
        
        else:
            # Default case
            print(f"⚠️ Unknown request type: {request_type}")
            if employee.report_to:
                return employee.report_to
            return None
    
    # ✅ NORMAL MANAGER CHAIN (Common role wale)
    if employee.role in ["Common", "Manager", "Team Lead", "Supervisor"]:
        if employee.report_to:
            try:
                next_user = User.objects.get(employee_id=employee.report_to)
                print(f"✅ Manager chain: {employee.employee_id} → {next_user.employee_id} ({next_user.role})")
                
                # Agar next user bhi manager hai, toh chain continue karo
                if next_user.role in ["Common", "Manager", "Team Lead", "Supervisor"]:
                    return get_next_approver(next_user, request_type, new_chain)
                else:
                    # Agar next user special role hai
                    return next_user.employee_id
                    
            except User.DoesNotExist:
                print(f"❌ Next manager {employee.report_to} not found")
        
        # Agar report_to nahi hai, toh Finance Verification dhoondo
        finance_user = User.objects.filter(role="Finance Verification").first()
        if finance_user:
            print(f"📭 No report_to, sending to Finance: {finance_user.employee_id}")
            return finance_user.employee_id
        
        return None
    
    # ✅ HR APPROVAL FLOW
    if employee.role == "HR":
        print(f"🔍 HR user - checking next approver...")
        
        # HR ke baad CEO jana chahiye (for both reimbursement and advance)
        ceo_user = User.objects.filter(role="CEO").first()
        if ceo_user:
            print(f"✅ HR → CEO: {ceo_user.employee_id}")
            return ceo_user.employee_id
        
        # Agar CEO nahi hai, toh report_to chain follow karo
        if employee.report_to:
            print(f"⚠️ CEO not found, using report_to: {employee.report_to}")
            return employee.report_to
        
        print(f"❌ HR: No CEO found and no report_to")
        return None
    
    # ✅ CEO APPROVAL FLOW
    if employee.role == "CEO":
        print(f"🔍 CEO user - checking next approver...")
        
        # CEO ke baad Finance Payment jana chahiye
        finance_payment_user = User.objects.filter(role="Finance Payment").first()
        if finance_payment_user:
            print(f"✅ CEO → Finance Payment: {finance_payment_user.employee_id}")
            return finance_payment_user.employee_id
        
        # Agar Finance Payment nahi hai, toh report_to chain follow karo
        if employee.report_to:
            print(f"⚠️ Finance Payment not found, using report_to: {employee.report_to}")
            return employee.report_to
        
        print(f"🎯 CEO is final approver - no next approver")
        return None
    
    # ✅ Finance Payment is FINAL
    if employee.role == "Finance Payment":
        print(f"🎯 Finance Payment is final approver - no next approver")
        return None
    
    # ✅ DEFAULT: Use report_to chain
    if employee.report_to:
        try:
            next_user = User.objects.get(employee_id=employee.report_to)
            print(f"✅ Default chain: {employee.employee_id} → {next_user.employee_id} ({next_user.role})")
            return next_user.employee_id
        except User.DoesNotExist:
            print(f"❌ Next approver {employee.report_to} not found")
    
    # ✅ END OF CHAIN
    print(f"📭 End of chain for {employee.employee_id}")
    return None
def process_approval(request_obj, approver_employee, approved=True, rejection_reason=None):
    request_type = 'reimbursement' if hasattr(request_obj, 'date') else 'advance'
    
    if not approved:
        # Rejection logic
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

    # ✅ CREATE APPROVAL HISTORY
    ApprovalHistory.objects.create(
        request_type=request_type,
        request_id=request_obj.id,
        approver_id=approver_employee.employee_id,
        approver_name=approver_employee.fullName,
        action='approved',
        comments=f'Approved by {approver_employee.role}'
    )

    # ✅ GET NEXT APPROVER WITH REQUEST TYPE
    next_approver_id = get_next_approver(approver_employee, request_type)
    
    if next_approver_id:
        try:
            next_user = User.objects.get(employee_id=next_approver_id)
            
            # Set current approver
            request_obj.current_approver_id = next_approver_id
            request_obj.status = "Pending"
            
            # ✅ DYNAMIC STEP CALCULATION
            current_step = request_obj.currentStep if hasattr(request_obj, 'currentStep') else 1
            
            if next_user.role == "Finance Verification":
                request_obj.currentStep = 3  # Finance step
                print(f"✅ → Finance Verification: Step {current_step} → 3")
                
            elif next_user.role == "HR":
                request_obj.currentStep = 4  # HR step
                print(f"✅ → HR: Step {current_step} → 4")
                
            elif next_user.role == "CEO":
                if request_type == "advance":
                    request_obj.currentStep = 5  # Advance CEO step
                else:
                    request_obj.currentStep = 4  # Reimbursement CEO step
                print(f"✅ → CEO: Step {current_step} → {request_obj.currentStep}")
                
            elif next_user.role == "Finance Payment":
                request_obj.currentStep = 6  # Payment step
                print(f"✅ → Finance Payment: Step {current_step} → 6")
                
            else:
                # Normal manager chain
                request_obj.currentStep = current_step + 1
                print(f"✅ Manager chain: Step {current_step} → {request_obj.currentStep}")
            
            # Set approval flags
            if approver_employee.role == "Finance Verification":
                request_obj.approved_by_finance = True
            elif approver_employee.role == "HR":
                request_obj.approved_by_hr = True
            elif approver_employee.role == "CEO":
                request_obj.approved_by_ceo = True
            
        except User.DoesNotExist:
            # Next approver not found
            print(f"❌ Next approver {next_approver_id} not found")
            request_obj.status = "Approved"
            request_obj.current_approver_id = None
            request_obj.final_approver = approver_employee.employee_id
    
    else:
        # No next approver - final approval
        request_obj.status = "Approved"
        request_obj.current_approver_id = None
        request_obj.final_approver = approver_employee.employee_id
        
        # If CEO approved, assign to Finance Payment
        if approver_employee.role == "CEO":
            request_obj.approved_by_ceo = True
            finance_payment_user = User.objects.filter(role="Finance Payment").first()
            if finance_payment_user:
                request_obj.current_approver_id = finance_payment_user.employee_id
                request_obj.status = "Pending"  # Back to pending for payment
                request_obj.currentStep = 6

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

class ApproverCSVDownloadView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        try:
            period = request.GET.get('period', '1 Month')
            approver_id = request.user.employee_id
            
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

            # Get approval history for this approver within date range
            approval_history = ApprovalHistory.objects.filter(
                approver_id=approver_id,
                timestamp__date__range=[start_date, end_date]
            ).order_by('-timestamp')

            # Create CSV response
            response = HttpResponse(content_type='text/csv')
            response['Content-Disposition'] = f'attachment; filename="approver_actions_{period.replace(" ", "_").lower()}_{end_date}.csv"'
            
            writer = csv.writer(response)
            # Enhanced header with approval details
            writer.writerow([
                'S.No', 'Request Type', 'Request ID', 'Employee ID', 'Employee Name',
                'Amount', 'Action', 'Action Date', 'Comments', 'Project ID', 'Project Name'
            ])
            
            # Write approval history data
            for i, approval in enumerate(approval_history, 1):
                # Get request details
                try:
                    if approval.request_type == 'reimbursement':
                        req = Reimbursement.objects.get(id=approval.request_id)
                        amount = req.amount
                        employee_name = req.employee.fullName
                        employee_id = req.employee.employee_id
                        project_id = req.project_id
                        project_name = getattr(req, 'project_name', '')
                    else:
                        req = AdvanceRequest.objects.get(id=approval.request_id)
                        amount = req.amount
                        employee_name = req.employee.fullName
                        employee_id = req.employee.employee_id
                        project_id = req.project_id
                        project_name = req.project_name
                    
                    writer.writerow([
                        i,
                        approval.request_type.title(),
                        approval.request_id,
                        employee_id,
                        employee_name,
                        f'₹{amount}',
                        approval.action.title(),
                        approval.timestamp.strftime('%Y-%m-%d %H:%M') if approval.timestamp else '-',
                        approval.comments or 'No comments',
                        project_id or '',
                        project_name or ''
                    ])
                except (Reimbursement.DoesNotExist, AdvanceRequest.DoesNotExist):
                    # If request doesn't exist anymore, still include the approval record
                    writer.writerow([
                        i,
                        approval.request_type.title(),
                        approval.request_id,
                        'Unknown',
                        'Unknown Employee',
                        '₹0',
                        approval.action.title(),
                        approval.timestamp.strftime('%Y-%m-%d %H:%M') if approval.timestamp else '-',
                        approval.comments or 'No comments',
                        '',
                        ''
                    ])
            
            return response
            
        except Exception as e:
            return Response(
                {'error': f'Failed to generate CSV: {str(e)}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
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
        
        # ✅ FIXED: GET ONLY REQUESTS WHERE CEO IS CURRENT APPROVER
        # Don't include requests that are still with HR
        
        # 1. Reimbursements where CEO is current approver
        reimbursements_pending = Reimbursement.objects.filter(
            current_approver_id=ceo_employee_id,
            status="Pending"
        ).select_related('employee')
        
        # 2. Advances where CEO is current approver AND HR has approved
        advances_pending = AdvanceRequest.objects.filter(
            current_approver_id=ceo_employee_id,
            status="Pending"
        ).select_related('employee')
        
        # ✅ REMOVED: Finance approved requests that haven't been processed by HR
        # These should NOT show in CEO dashboard until HR approves them
        
        print(f"📊 CEO Dashboard - Reimbursements: {len(reimbursements_pending)}, Advances: {len(advances_pending)}")
        
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
                "request_type": "reimbursement",
                "approved_by_finance": reimbursement.approved_by_finance,
                "current_approver_id": reimbursement.current_approver_id,
                "project_id": reimbursement.project_id,
                "project_name": getattr(reimbursement, 'project_name', None),
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
                "request_type": "advance",
                "approved_by_finance": advance.approved_by_finance,
                "approved_by_hr": advance.approved_by_hr,  # ✅ ADD HR APPROVAL STATUS
                "current_approver_id": advance.current_approver_id,
                "project_id": advance.project_id,
                "project_name": advance.project_name,
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
                "advances_count": len(pending_advances_data),
                "note": "Only shows requests where CEO is current approver. Advances require HR approval first."
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

        # NEW: Department-wise statistics
        department_stats = []
        all_departments = User.objects.values_list('department', flat=True).distinct()
        
        for dept in all_departments:
            if dept:  # Skip empty departments
                dept_reimbursements = Reimbursement.objects.filter(
                    employee__department=dept,
                    date__gte=month_start,
                    status='Approved'
                )
                dept_advances = AdvanceRequest.objects.filter(
                    employee__department=dept,
                    request_date__gte=month_start,
                    status='Approved'
                )
                
                dept_amount = sum(r.amount for r in dept_reimbursements) + sum(a.amount for a in dept_advances)
                dept_count = dept_reimbursements.count() + dept_advances.count()
                
                if dept_count > 0:
                    department_stats.append({
                        'department': dept,
                        'amount': float(dept_amount),
                        'count': dept_count
                    })

        # NEW: Performance metrics for real-time dashboard
        # Average processing time (from submission to CEO approval)
        ceo_approved_requests = ApprovalHistory.objects.filter(
            approver_id=request.user.employee_id,
            action='approved',
            timestamp__gte=month_start
        )
        
        total_processing_time = 0
        processing_count = 0
        
        for approval in ceo_approved_requests:
            try:
                if approval.request_type == 'reimbursement':
                    req = Reimbursement.objects.get(id=approval.request_id)
                else:
                    req = AdvanceRequest.objects.get(id=approval.request_id)
                
                if req.created_at and approval.timestamp:
                    processing_time = approval.timestamp - req.created_at
                    total_processing_time += processing_time.total_seconds() / 3600  # Convert to hours
                    processing_count += 1
            except (Reimbursement.DoesNotExist, AdvanceRequest.DoesNotExist):
                continue
        
        avg_processing_time = total_processing_time / processing_count if processing_count > 0 else 0

        # NEW: Pending CEO actions count
        pending_ceo_actions = Reimbursement.objects.filter(
            current_approver_id=request.user.employee_id,
            status="Pending"
        ).count() + AdvanceRequest.objects.filter(
            current_approver_id=request.user.employee_id,
            status="Pending"
        ).count()

        # NEW: Weekly approved count
        week_start = today - timedelta(days=today.weekday())
        weekly_approved = Reimbursement.objects.filter(
            date__gte=week_start,
            status='Approved'
        ).count() + AdvanceRequest.objects.filter(
            request_date__gte=week_start,
            status='Approved'
        ).count()

        # NEW: Today's requests
        todays_requests = Reimbursement.objects.filter(
            created_at__date=today
        ).count() + AdvanceRequest.objects.filter(
            created_at__date=today
        ).count()

        # Add these to your existing analytics data
        analytics_data = {
            # Enhanced analytics as requested
            'monthly_approved_count': monthly_approved_count,
            'monthly_spending': float(monthly_approved_spending),
            'approval_rate': float(approval_rate),
            'average_request_amount': float(average_request_amount),
            'total_requests_this_month': total_requests_this_month,
            'monthly_growth': float(monthly_growth),
            
            # Department statistics
            'department_stats': department_stats,
            
            # Performance metrics for real-time dashboard
            'avg_processing_time': round(avg_processing_time, 1),
            'pending_ceo_actions': pending_ceo_actions,
            'weekly_approved': weekly_approved,
            'todays_requests': todays_requests,
            
            # Keep your existing fields
            'reimbursement_count': total_reimbursements_this_month,
            'advance_count': total_advances_this_month,
            'approved_count': monthly_approved_count,
            'rejected_count': Reimbursement.objects.filter(date__gte=month_start, status='Rejected').count() + AdvanceRequest.objects.filter(request_date__gte=month_start, status='Rejected').count(),
            'pending_count': Reimbursement.objects.filter(date__gte=month_start, status='Pending').count() + AdvanceRequest.objects.filter(request_date__gte=month_start, status='Pending').count(),
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
                'submission_date': reimbursement.created_at.strftime('%Y-%m-%d') if reimbursement.created_at else None,
                # ✅ ADD PROJECT DATA TO HISTORY
                'project_id': reimbursement.project_id,
                'project_name': getattr(reimbursement, 'project_name', None),
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
                'submission_date': advance.created_at.strftime('%Y-%m-%d') if advance.created_at else None,
                # ✅ ADD PROJECT DATA TO HISTORY
                'project_id': advance.project_id,
                'project_name': advance.project_name,
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
                # ✅ FIXED: Strict check - only if CEO is current approver
                is_authorized = (
                    reimbursement.current_approver_id == request.user.employee_id
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
                # ✅ FIXED: Strict check - only if CEO is current approver
                is_authorized = (
                    advance.current_approver_id == request.user.employee_id
                )
                
                if not is_authorized:
                    return Response(
                        {'error': 'Not authorized to approve this request'},
                        status=status.HTTP_403_FORBIDDEN
                    )
                
                # ✅ ADDITIONAL CHECK: Advance must be approved by HR first
                if not advance.approved_by_hr:
                    return Response({
                        'error': 'Advance request must be approved by HR before CEO can approve'
                    }, status=status.HTTP_400_BAD_REQUEST)
                
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
                # ✅ FIXED: Strict check - only if CEO is current approver
                is_authorized = (
                    reimbursement.current_approver_id == request.user.employee_id
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
                # ✅ FIXED: Strict check - only if CEO is current approver
                is_authorized = (
                    advance.current_approver_id == request.user.employee_id
                )
                
                if not is_authorized:
                    return Response(
                        {'error': 'Not authorized to reject this request'},
                        status=status.HTTP_403_FORBIDDEN
                    )
                
                # ✅ ADDITIONAL CHECK: Advance must be approved by HR first
                if not advance.approved_by_hr:
                    return Response({
                        'error': 'Advance request must be approved by HR before CEO can reject'
                    }, status=status.HTTP_400_BAD_REQUEST)
                
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
        # Enhanced CSV headers with project data
        writer.writerow([
            'Request ID', 'Employee ID', 'Employee Name', 'Department',
            'Request Type', 'Amount', 'Submission Date', 'Status',
            'CEO Action', 'Rejection Reason', 'Description', 'Payment Count',
            'Project ID', 'Project Name',  # ✅ ADDED PROJECT COLUMNS
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
                payment_count,
                reimbursement.project_id or '',  # ✅ ADDED PROJECT DATA
                getattr(reimbursement, 'project_name', '') or '',
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
                payment_count,
                advance.project_id or '',  # ✅ ADDED PROJECT DATA
                advance.project_name or '',
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

        # ✅ FIXED: Build proper stepper flow with next approver
        timeline = self._build_stepper_with_next_approver(request_obj, approval_history)
        
        return Response({
            'timeline': timeline,
            'current_status': request_obj.status,
            'current_step': self._get_current_step(timeline),
            'is_rejected': request_obj.status == 'Rejected',
            'next_approver': self._get_next_approver_info(request_obj)  # ✅ ADD NEXT APPROVER INFO
        })

    def _build_stepper_with_next_approver(self, request_obj, approval_history):
        """Build stepper flow showing next approver - FIXED VERSION"""
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
            'comments': 'Request submitted by employee',
            'step_number': 1
        })

        # ✅ ADD ALL COMPLETED APPROVAL STEPS FROM HISTORY
        step_counter = 2
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
                    'comments': history.comments,
                    'step_number': step_counter
                })
                step_counter += 1
            elif history.action == 'forwarded':
                timeline.append({
                    'step': f'Forwarded by {history.approver_name}',
                    'approver_name': history.approver_name,
                    'approver_id': history.approver_id,
                    'timestamp': history.timestamp,
                    'status': 'completed',
                    'action': 'forwarded',
                    'step_type': self._get_step_type(history.approver_id),
                    'comments': history.comments,
                    'step_number': step_counter
                })
                step_counter += 1
            elif history.action == 'rejected':
                timeline.append({
                    'step': f'Rejected by {history.approver_name}',
                    'approver_name': history.approver_name,
                    'approver_id': history.approver_id,
                    'timestamp': history.timestamp,
                    'status': 'rejected',
                    'action': 'rejected',
                    'step_type': self._get_step_type(history.approver_id),
                    'comments': history.comments,
                    'step_number': step_counter
                })
                step_counter += 1

        # ✅ ADD NEXT APPROVER STEP IF REQUEST IS STILL PENDING
        if request_obj.status == 'Pending' and request_obj.current_approver_id:
            next_approver_info = self._get_next_approver_info(request_obj)
            if next_approver_info:
                timeline.append({
                    'step': f'Pending with {next_approver_info["approver_name"]}',
                    'approver_name': next_approver_info["approver_name"],
                    'approver_id': next_approver_info["approver_id"],
                    'approver_role': next_approver_info["approver_role"],
                    'timestamp': None,  # No timestamp yet
                    'status': 'pending',
                    'action': 'pending',
                    'step_type': next_approver_info["approver_role"].lower().replace(' ', '_'),
                    'comments': f'Awaiting approval from {next_approver_info["approver_role"]}',
                    'step_number': step_counter,
                    'is_next_approver': True  # ✅ FLAG TO IDENTIFY NEXT APPROVER
                })
                step_counter += 1

        # ✅ ADD FINANCE PAYMENT STEP IF APPROVED BY CEO
        if request_obj.status == 'Approved' and request_obj.approved_by_ceo:
            # Check if already assigned to Finance Payment
            if request_obj.current_approver_id:
                finance_payment_info = self._get_next_approver_info(request_obj)
                timeline.append({
                    'step': 'Ready for Payment Processing',
                    'approver_name': finance_payment_info["approver_name"],
                    'approver_id': finance_payment_info["approver_id"],
                    'approver_role': finance_payment_info["approver_role"],
                    'timestamp': None,
                    'status': 'pending',
                    'action': 'pending',
                    'step_type': 'finance_payment',
                    'comments': 'Ready for payment processing by Finance Team',
                    'step_number': step_counter,
                    'is_next_approver': True
                })
            else:
                timeline.append({
                    'step': 'Ready for Payment Processing',
                    'approver_name': 'Finance Payment Team',
                    'approver_id': 'finance_payment',
                    'approver_role': 'Finance Payment',
                    'timestamp': None,
                    'status': 'pending',
                    'action': 'pending',
                    'step_type': 'finance_payment',
                    'comments': 'Ready for payment processing',
                    'step_number': step_counter,
                    'is_next_approver': True
                })
            step_counter += 1

        # ✅ ADD PAYMENT PROCESSED STEP IF PAID
        if request_obj.status == 'Paid':
            timeline.append({
                'step': 'Payment Processed',
                'approver_name': 'Finance Payment',
                'approver_id': 'finance_payment',
                'approver_role': 'Finance Payment',
                'timestamp': request_obj.payment_date,
                'status': 'paid',
                'action': 'paid',
                'step_type': 'finance_payment',
                'comments': 'Payment has been processed successfully',
                'step_number': step_counter
            })

        return timeline

    def _get_next_approver_info(self, request_obj):
        """Get detailed information about the next approver"""
        if not request_obj.current_approver_id:
            return None
            
        try:
            next_approver = User.objects.get(employee_id=request_obj.current_approver_id)
            return {
                'approver_name': next_approver.fullName,
                'approver_id': next_approver.employee_id,
                'approver_role': next_approver.role,
                'approver_email': next_approver.email,
                'approver_department': next_approver.department
            }
        except User.DoesNotExist:
            return {
                'approver_name': 'Unknown Approver',
                'approver_id': request_obj.current_approver_id,
                'approver_role': 'Approver',
                'approver_email': '',
                'approver_department': ''
            }

    def _get_step_type(self, approver_id):
        """Determine step type based on approver role"""
        try:
            approver = User.objects.get(employee_id=approver_id)
            return approver.role.lower().replace(' ', '_')
        except User.DoesNotExist:
            if approver_id == 'system':
                return 'system'
            return 'unknown'

    def _get_current_step(self, timeline):
        """Get current active step number"""
        for step in reversed(timeline):
            if step['status'] in ['pending']:
                return step['step_number']
        # If no pending steps, return the last completed step
        return timeline[-1]['step_number'] if timeline else 1

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
        
        # ✅ FIXED: Get CEO approved requests that need payment processing WITH COMPLETE PROJECT DATA
        ready_for_payment = []
        
        # CEO approved reimbursements that need payment (status=Approved)
        reimbursement_ready = Reimbursement.objects.filter(
            Q(current_approver_id=request.user.employee_id) |  # Either assigned to Finance Payment
            Q(status="Approved", approved_by_ceo=True)  # OR CEO approved but not yet paid
        ).exclude(status="Paid").exclude(status="Rejected").select_related('employee')
        
        for reimbursement in reimbursement_ready:
            # ✅ CRITICAL FIX: INCLUDE COMPLETE PROJECT DATA FROM REIMBURSEMENT TABLE
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
                # ✅ COMPLETE PROJECT DATA FROM REIMBURSEMENT TABLE
                'project_id': reimbursement.project_id,
                'project_name': getattr(reimbursement, 'project_name', None),  # Use getattr for safety
                'project_code': getattr(reimbursement, 'project_code', reimbursement.project_id),  # Fallback to project_id
                'approved_date': reimbursement.updated_at,
                'submitted_date': reimbursement.created_at,
                'current_approver': reimbursement.current_approver_id,
                'attachments': reimbursement.attachments if reimbursement.attachments else [],
                'payments': reimbursement.payments if reimbursement.payments else [],
                # ✅ ADDITIONAL FIELDS FOR BETTER DATA
                'approved_by_ceo': reimbursement.approved_by_ceo,
                'final_approver': reimbursement.final_approver,
            })

        # CEO approved advances that need payment (status=Approved)
        advance_ready = AdvanceRequest.objects.filter(
            Q(current_approver_id=request.user.employee_id) |  # Either assigned to Finance Payment
            Q(status="Approved", approved_by_ceo=True)  # OR CEO approved but not yet paid
        ).exclude(status="Paid").exclude(status="Rejected").select_related('employee')
        
        for advance in advance_ready:
            # ✅ CRITICAL FIX: INCLUDE COMPLETE PROJECT DATA FROM ADVANCE TABLE
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
                # ✅ COMPLETE PROJECT DATA FROM ADVANCE TABLE
                'project_id': advance.project_id,
                'project_name': advance.project_name,
                'project_code': getattr(advance, 'project_code', advance.project_id),  # Fallback to project_id
                'approved_date': advance.updated_at,
                'submitted_date': advance.created_at,
                'current_approver': advance.current_approver_id,
                'attachments': advance.attachments if advance.attachments else [],
                'payments': advance.payments if advance.payments else [],
                # ✅ ADDITIONAL FIELDS FOR BETTER DATA
                'approved_by_ceo': advance.approved_by_ceo,
                'final_approver': advance.final_approver,
            })

        # ✅ FIXED: Paid requests history - INCLUDE COMPLETE PROJECT DATA
        paid_requests = []
        reimbursement_paid = Reimbursement.objects.filter(status="Paid").select_related('employee')[:50]
        advance_paid = AdvanceRequest.objects.filter(status="Paid").select_related('employee')[:50]
        
        for req in list(reimbursement_paid) + list(advance_paid):
            # Determine if it's reimbursement or advance
            is_reimbursement = hasattr(req, 'date')
            
            paid_requests.append({
                'id': req.id,
                'employee_id': req.employee.employee_id,
                'employee_name': req.employee.fullName,
                'employee_avatar': request.build_absolute_uri(req.employee.avatar.url) if req.employee.avatar else None,
                'amount': float(req.amount),
                'description': req.description,
                'request_type': 'reimbursement' if is_reimbursement else 'advance',
                'payment_date': req.payment_date,
                'submitted_date': req.created_at,
                # ✅ COMPLETE PROJECT DATA FOR PAID REQUESTS
                'project_id': req.project_id,
                'project_name': getattr(req, 'project_name', None),  # Advances have project_name
                'project_code': getattr(req, 'project_code', req.project_id),  # Use project_id as fallback
                'attachments': req.attachments if req.attachments else [],
                'payments': req.payments if req.payments else [],
            })

        # ✅ ADD DEBUG LOGGING TO VERIFY DATA
        print(f"🔍 Finance Payment Dashboard - Ready for payment: {len(ready_for_payment)}")
        print(f"🔍 Finance Payment Dashboard - Paid requests: {len(paid_requests)}")
        
        # Log first few records to verify project data
        for i, req in enumerate(ready_for_payment[:3]):
            print(f"🔍 Ready Request {i}: ID={req['id']}, Type={req['request_type']}, "
                  f"Project ID={req.get('project_id')}, Project Name={req.get('project_name')}")
        
        for i, req in enumerate(paid_requests[:3]):
            print(f"🔍 Paid Request {i}: ID={req['id']}, Type={req['request_type']}, "
                  f"Project ID={req.get('project_id')}, Project Name={req.get('project_name')}")

        return Response({
            'ready_for_payment': ready_for_payment,
            'paid_requests': paid_requests,
            'pending_payment_count': len(ready_for_payment),
            'total_paid_count': len(paid_requests),
            'debug_info': {
                'total_ready': len(ready_for_payment),
                'total_paid': len(paid_requests),
                'reimbursements_ready': len([r for r in ready_for_payment if r['request_type'] == 'reimbursement']),
                'advances_ready': len([r for r in ready_for_payment if r['request_type'] == 'advance']),
            }
        })
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

            # ✅ DEBUG: Log project data before marking as paid
            print(f"💰 Marking as paid - Request ID: {obj.id}, Type: {request_type}")
            print(f"💰 Project Data - ID: {obj.project_id}, Name: {getattr(obj, 'project_name', 'None')}")

            # Mark as paid (PROJECT DATA IS PRESERVED AUTOMATICALLY)
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
    
class EmployeeProjectSpendingView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        """
        Get spending data for specific employee and project combination
        Used for Finance Payment dashboard reports
        """
        if request.user.role != "Finance Payment":
            return Response(
                {"detail": "Access denied. Finance Payment role required."}, 
                status=status.HTTP_403_FORBIDDEN
            )
        
        employee_id = request.GET.get('employee_id')
        project_identifier = request.GET.get('project_identifier')
        period = request.GET.get('period', 'all_time')
        
        if not employee_id or not project_identifier:
            return Response(
                {"error": "employee_id and project_identifier are required"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Calculate date range based on period
        today = timezone.now().date()
        if period == '1_month':
            start_date = today - timedelta(days=30)
        elif period == '3_months':
            start_date = today - timedelta(days=90)
        elif period == '6_months':
            start_date = today - timedelta(days=180)
        else:  # all_time
            start_date = today - timedelta(days=365*5)  # 5 years back
        
        try:
            # Verify employee exists
            employee = User.objects.get(employee_id=employee_id)
        except User.DoesNotExist:
            return Response(
                {"error": f"Employee with ID {employee_id} not found"},
                status=status.HTTP_404_NOT_FOUND
            )
        
        # Get reimbursements for employee and project
        reimbursements = Reimbursement.objects.filter(
            employee_id=employee_id,
            created_at__date__gte=start_date
        )
        
        # Enhanced project matching for reimbursements
        project_reimbursements = []
        for reimb in reimbursements:
            # Multiple ways to match project
            project_match = (
                str(reimb.project_id) == str(project_identifier) or
                (hasattr(reimb, 'project_name') and 
                 reimb.project_name and 
                 project_identifier.lower() in reimb.project_name.lower()) or
                (hasattr(reimb, 'project_code') and 
                 reimb.project_code and 
                 str(reimb.project_code) == str(project_identifier))
            )
            
            if project_match:
                project_reimbursements.append(reimb)
        
        # Get advances for employee and project
        advances = AdvanceRequest.objects.filter(
            employee_id=employee_id,
            created_at__date__gte=start_date
        )
        
        # Enhanced project matching for advances
        project_advances = []
        for advance in advances:
            # Multiple ways to match project
            project_match = (
                str(advance.project_id) == str(project_identifier) or
                (advance.project_name and 
                 project_identifier.lower() in advance.project_name.lower()) or
                (hasattr(advance, 'project_code') and 
                 advance.project_code and 
                 str(advance.project_code) == str(project_identifier))
            )
            
            if project_match:
                project_advances.append(advance)
        
        # Combine and format results
        all_requests = list(project_reimbursements) + list(project_advances)
        
        if not all_requests:
            return Response({
                "employee_id": employee_id,
                "employee_name": employee.fullName,
                "project_identifier": project_identifier,
                "period": period,
                "total_requests": 0,
                "total_amount": 0,
                "requests": [],
                "message": "No matching requests found for the specified criteria"
            })
        
        # Calculate totals
        total_amount = sum(float(req.amount) for req in all_requests)
        
        # Format response data
        requests_data = []
        for req in all_requests:
            is_reimbursement = hasattr(req, 'date')
            request_data = {
                'id': req.id,
                'request_type': 'reimbursement' if is_reimbursement else 'advance',
                'amount': float(req.amount),
                'description': req.description,
                'status': req.status,
                'submitted_date': req.created_at.strftime('%Y-%m-%d') if req.created_at else None,
                'approved_date': req.updated_at.strftime('%Y-%m-%d') if req.status == 'Approved' else None,
                'payment_date': req.payment_date.strftime('%Y-%m-%d') if req.payment_date else None,
                'project_id': req.project_id,
                'project_name': getattr(req, 'project_name', None),
            }
            requests_data.append(request_data)
        
        return Response({
            "employee_id": employee_id,
            "employee_name": employee.fullName,
            "project_identifier": project_identifier,
            "period": period,
            "total_requests": len(all_requests),
            "total_amount": round(total_amount, 2),
            "reimbursement_count": len(project_reimbursements),
            "advance_count": len(project_advances),
            "requests": requests_data
        })
 # ✅ ADD THESE NEW FINANCE VERIFICATION ENDPOINTS TO YOUR EXISTING views.py
class FinanceVerificationHistoryView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        """
        Get verified/rejected requests history for Finance Verification Dashboard - FIXED VERSION
        """
        if request.user.role != "Finance Verification":
            return Response(
                {"detail": "Access denied. Finance Verification role required."}, 
                status=status.HTTP_403_FORBIDDEN
            )
        
        try:
            finance_user_id = request.user.employee_id
            
            print(f"🔍 Loading history for Finance User: {finance_user_id}")
            
            # ✅ FIXED: Get approval history for this finance user
            finance_approvals = ApprovalHistory.objects.filter(
                approver_id=finance_user_id
            ).order_by('-timestamp')
            
            verified_requests = []
            
            for approval in finance_approvals:
                try:
                    if approval.request_type == 'reimbursement':
                        request_obj = Reimbursement.objects.get(id=approval.request_id)
                        employee = request_obj.employee
                        project_name = getattr(request_obj, 'project_name', None)
                    else:
                        request_obj = AdvanceRequest.objects.get(id=approval.request_id)
                        employee = request_obj.employee
                        project_name = request_obj.project_name
                    
                    # Build request data
                    request_data = {
                        'id': request_obj.id,
                        'employee_id': employee.employee_id,
                        'employee_name': employee.fullName,
                        'employee_avatar': request.build_absolute_uri(employee.avatar.url) if employee.avatar else None,
                        'amount': float(request_obj.amount),
                        'description': request_obj.description,
                        'request_type': approval.request_type,
                        'status': request_obj.status,
                        'verification_status': 'approved' if approval.action == 'approved' else 'rejected',
                        'submitted_date': request_obj.created_at.isoformat() if request_obj.created_at else None,
                        'verification_date': approval.timestamp.isoformat() if approval.timestamp else None,
                        'rejection_reason': request_obj.rejection_reason if approval.action == 'rejected' else None,
                        'project_id': request_obj.project_id,
                        'project_name': project_name,
                        'current_approver_id': request_obj.current_approver_id,
                        'finance_action': approval.action,
                        'finance_comments': approval.comments,
                    }
                    
                    verified_requests.append(request_data)
                    
                except (Reimbursement.DoesNotExist, AdvanceRequest.DoesNotExist):
                    # Skip if request no longer exists
                    continue
            
            print(f"📚 Finance History Loaded: {len(verified_requests)} requests")
            
            return Response({
                'verified_requests': verified_requests,
                'count': len(verified_requests),
                'message': 'Successfully loaded verification history'
            })
            
        except Exception as e:
            print(f"❌ Error in FinanceVerificationHistoryView: {str(e)}")
            return Response({'error': f'Failed to load history: {str(e)}'}, status=500)
        
class FinanceVerificationInsightsView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        """
        Get real-time verification insights for Finance Verification Dashboard - FIXED VERSION
        """
        if request.user.role != "Finance Verification":
            return Response(
                {"detail": "Access denied. Finance Verification role required."}, 
                status=status.HTTP_403_FORBIDDEN
            )
        
        try:
            today = timezone.now().date()
            month_start = today.replace(day=1)
            finance_user_id = request.user.employee_id
            
            print(f"🔍 Loading insights for Finance User: {finance_user_id}")
            
            # ✅ FIXED: Get requests assigned to current finance user
            reimbursement_pending = Reimbursement.objects.filter(
                current_approver_id=finance_user_id,
                status="Pending"
            ).count()
            
            advance_pending = AdvanceRequest.objects.filter(
                current_approver_id=finance_user_id,
                status="Pending"
            ).count()
            
            total_pending = reimbursement_pending + advance_pending
            
            # ✅ FIXED: Monthly pending (submitted this month AND assigned to finance)
            reimbursement_monthly = Reimbursement.objects.filter(
                current_approver_id=finance_user_id,
                status="Pending",
                created_at__gte=month_start
            ).count()
            
            advance_monthly = AdvanceRequest.objects.filter(
                current_approver_id=finance_user_id,
                status="Pending", 
                created_at__gte=month_start
            ).count()
            
            total_monthly_pending = reimbursement_monthly + advance_monthly
            
            # ✅ FIXED: Amount calculations for pending requests
            total_amount = 0
            monthly_amount = 0
            
            # Total pending amount
            pending_reimbursements = Reimbursement.objects.filter(
                current_approver_id=finance_user_id,
                status="Pending"
            )
            for req in pending_reimbursements:
                total_amount += float(req.amount)
                
            pending_advances = AdvanceRequest.objects.filter(
                current_approver_id=finance_user_id,
                status="Pending"
            )
            for req in pending_advances:
                total_amount += float(req.amount)
            
            # Monthly pending amount
            monthly_reimbursements = Reimbursement.objects.filter(
                current_approver_id=finance_user_id,
                status="Pending",
                created_at__gte=month_start
            )
            for req in monthly_reimbursements:
                monthly_amount += float(req.amount)
                
            monthly_advances = AdvanceRequest.objects.filter(
                current_approver_id=finance_user_id,
                status="Pending",
                created_at__gte=month_start
            )
            for req in monthly_advances:
                monthly_amount += float(req.amount)
            
            # ✅ FIXED: Verified requests (processed by this finance user)
            # Get requests where finance user approved them
            finance_approved_reimbursements = ApprovalHistory.objects.filter(
                approver_id=finance_user_id,
                request_type='reimbursement',
                action='approved'
            ).values_list('request_id', flat=True)
            
            finance_approved_advances = ApprovalHistory.objects.filter(
                approver_id=finance_user_id,
                request_type='advance', 
                action='approved'
            ).values_list('request_id', flat=True)
            
            reimbursement_verified = len(finance_approved_reimbursements)
            advance_verified = len(finance_approved_advances)
            total_verified = reimbursement_verified + advance_verified
            
            # ✅ FIXED: Monthly verified
            reimbursement_monthly_verified = ApprovalHistory.objects.filter(
                approver_id=finance_user_id,
                request_type='reimbursement',
                action='approved',
                timestamp__gte=month_start
            ).count()
            
            advance_monthly_verified = ApprovalHistory.objects.filter(
                approver_id=finance_user_id,
                request_type='advance',
                action='approved',
                timestamp__gte=month_start
            ).count()
            
            total_monthly_verified = reimbursement_monthly_verified + advance_monthly_verified
            
            # ✅ FIXED: Verified amount calculations
            verified_amount = 0
            monthly_verified_amount = 0
            
            # Total verified amount
            for req_id in finance_approved_reimbursements:
                try:
                    req = Reimbursement.objects.get(id=req_id)
                    verified_amount += float(req.amount)
                except Reimbursement.DoesNotExist:
                    continue
                    
            for req_id in finance_approved_advances:
                try:
                    req = AdvanceRequest.objects.get(id=req_id)
                    verified_amount += float(req.amount)
                except AdvanceRequest.DoesNotExist:
                    continue
            
            # Monthly verified amount
            monthly_reimb_ids = ApprovalHistory.objects.filter(
                approver_id=finance_user_id,
                request_type='reimbursement',
                action='approved',
                timestamp__gte=month_start
            ).values_list('request_id', flat=True)
            
            for req_id in monthly_reimb_ids:
                try:
                    req = Reimbursement.objects.get(id=req_id)
                    monthly_verified_amount += float(req.amount)
                except Reimbursement.DoesNotExist:
                    continue
                    
            monthly_advance_ids = ApprovalHistory.objects.filter(
                approver_id=finance_user_id,
                request_type='advance',
                action='approved', 
                timestamp__gte=month_start
            ).values_list('request_id', flat=True)
            
            for req_id in monthly_advance_ids:
                try:
                    req = AdvanceRequest.objects.get(id=req_id)
                    monthly_verified_amount += float(req.amount)
                except AdvanceRequest.DoesNotExist:
                    continue
            
            # ✅ FIXED: Performance metrics
            avg_processing_hours = self._calculate_average_processing_time(finance_user_id)
            success_rate = self._calculate_success_rate(finance_user_id)
            
            insights_data = {
                # Pending requests
                'total_pending': total_pending,
                'monthly_pending': total_monthly_pending,
                'total_amount': round(total_amount, 2),
                'monthly_amount': round(monthly_amount, 2),
                'reimbursement_count': reimbursement_pending,
                'advance_count': advance_pending,
                'reimbursement_monthly': reimbursement_monthly,
                'advance_monthly': advance_monthly,
                
                # Verified requests
                'total_verified': total_verified,
                'monthly_verified': total_monthly_verified,
                'verified_amount': round(verified_amount, 2),
                'monthly_verified_amount': round(monthly_verified_amount, 2),
                'reimbursement_verified': reimbursement_verified,
                'advance_verified': advance_verified,
                'reimbursement_monthly_verified': reimbursement_monthly_verified,
                'advance_monthly_verified': advance_monthly_verified,
                
                # Performance metrics
                'avg_processing_time': round(avg_processing_hours, 1),
                'success_rate': round(success_rate, 1),
                'total_pending_amount': round(total_amount, 2),
                'total_verified_amount': round(verified_amount, 2),
                
                # Debug info
                'debug': {
                    'finance_user_id': finance_user_id,
                    'month_start': month_start.isoformat(),
                    'today': today.isoformat()
                }
            }
            
            print(f"📊 Finance Insights Generated: {insights_data}")
            
            return Response(insights_data, status=status.HTTP_200_OK)
            
        except Exception as e:
            print(f"❌ Error in FinanceVerificationInsightsView: {str(e)}")
            return Response({'error': f'Failed to load insights: {str(e)}'}, status=500)

    def _calculate_average_processing_time(self, finance_user_id):
        """Calculate average processing time for finance verification - FIXED"""
        try:
            # Get approval history for this finance user
            finance_approvals = ApprovalHistory.objects.filter(
                approver_id=finance_user_id,
                action='approved'
            )
            
            total_hours = 0
            count = 0
            
            for approval in finance_approvals:
                # Get the request creation time
                if approval.request_type == 'reimbursement':
                    try:
                        request_obj = Reimbursement.objects.get(id=approval.request_id)
                        created_time = request_obj.created_at
                    except Reimbursement.DoesNotExist:
                        continue
                else:
                    try:
                        request_obj = AdvanceRequest.objects.get(id=approval.request_id)
                        created_time = request_obj.created_at
                    except AdvanceRequest.DoesNotExist:
                        continue
                
                # Calculate processing time (from submission to finance approval)
                if created_time and approval.timestamp:
                    processing_time = approval.timestamp - created_time
                    total_hours += processing_time.total_seconds() / 3600  # Convert to hours
                    count += 1
            
            return total_hours / count if count > 0 else 0.0
            
        except Exception as e:
            print(f"❌ Error calculating processing time: {e}")
            return 0.0

    def _calculate_success_rate(self, finance_user_id):
        """Calculate success rate for finance verification - FIXED"""
        try:
            # Get finance approvals
            approvals = ApprovalHistory.objects.filter(
                approver_id=finance_user_id,
                action='approved'
            ).count()
            
            # Get finance rejections
            rejections = ApprovalHistory.objects.filter(
                approver_id=finance_user_id,
                action='rejected'
            ).count()
            
            total_actions = approvals + rejections
            
            if total_actions == 0:
                return 100.0  # No actions yet, assume 100% success
                
            success_rate = (approvals / total_actions) * 100
            return success_rate
            
        except Exception as e:
            print(f"❌ Error calculating success rate: {e}")
            return 100.0
        
class FinanceVerificationEmployeeProjectReportView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        """
        Generate employee-project verification report for Finance Verification Dashboard
        """
        if request.user.role != "Finance Verification":
            return Response(
                {"detail": "Access denied. Finance Verification role required."}, 
                status=status.HTTP_403_FORBIDDEN
            )
        
        employee_id = request.GET.get('employee_id')
        project_identifier = request.GET.get('project_identifier')
        period = request.GET.get('period', 'all_time')
        
        if not employee_id or not project_identifier:
            return Response(
                {"error": "employee_id and project_identifier are required"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Calculate date range based on period
        today = timezone.now().date()
        if period == '1_month':
            start_date = today - timedelta(days=30)
        elif period == '3_months':
            start_date = today - timedelta(days=90)
        elif period == '6_months':
            start_date = today - timedelta(days=180)
        else:  # all_time
            start_date = today - timedelta(days=365*5)  # 5 years back
        
        try:
            # Verify employee exists
            employee = User.objects.get(employee_id=employee_id)
        except User.DoesNotExist:
            return Response(
                {"error": f"Employee with ID {employee_id} not found"},
                status=status.HTTP_404_NOT_FOUND
            )
        
        # Get ALL requests for employee (pending and verified)
        all_reimbursements = Reimbursement.objects.filter(
            employee_id=employee_id,
            created_at__date__gte=start_date
        )
        
        all_advances = AdvanceRequest.objects.filter(
            employee_id=employee_id,
            created_at__date__gte=start_date
        )
        
        # Enhanced project matching
        project_reimbursements = []
        for reimb in all_reimbursements:
            project_match = (
                str(reimb.project_id) == str(project_identifier) or
                (hasattr(reimb, 'project_name') and 
                 reimb.project_name and 
                 project_identifier.lower() in reimb.project_name.lower()) or
                (hasattr(reimb, 'project_code') and 
                 reimb.project_code and 
                 str(reimb.project_code) == str(project_identifier))
            )
            
            if project_match:
                project_reimbursements.append(reimb)
        
        project_advances = []
        for advance in all_advances:
            project_match = (
                str(advance.project_id) == str(project_identifier) or
                (advance.project_name and 
                 project_identifier.lower() in advance.project_name.lower()) or
                (hasattr(advance, 'project_code') and 
                 advance.project_code and 
                 str(advance.project_code) == str(project_identifier))
            )
            
            if project_match:
                project_advances.append(advance)
        
        # Combine all requests
        all_requests = list(project_reimbursements) + list(project_advances)
        
        if not all_requests:
            return Response({
                "employee_id": employee_id,
                "employee_name": employee.fullName,
                "project_identifier": project_identifier,
                "period": period,
                "total_requests": 0,
                "total_amount": 0,
                "pending_requests": 0,
                "verified_requests": 0,
                "requests": [],
                "message": "No matching requests found for the specified criteria"
            })
        
        # Calculate totals
        total_amount = sum(float(req.amount) for req in all_requests)
        pending_requests = len([req for req in all_requests if req.status == 'Pending'])
        verified_requests = len([req for req in all_requests if req.status in ['Approved', 'Rejected', 'Paid']])
        
        # Format response data
        requests_data = []
        for req in all_requests:
            is_reimbursement = hasattr(req, 'date')
            request_data = {
                'id': req.id,
                'request_type': 'reimbursement' if is_reimbursement else 'advance',
                'amount': float(req.amount),
                'description': req.description,
                'status': req.status,
                'submitted_date': req.created_at.strftime('%Y-%m-%d') if req.created_at else None,
                'approved_date': req.updated_at.strftime('%Y-%m-%d') if req.status == 'Approved' else None,
                'payment_date': req.payment_date.strftime('%Y-%m-%d') if req.payment_date else None,
                'project_id': req.project_id,
                'project_name': getattr(req, 'project_name', None),
                'approved_by_finance': getattr(req, 'approved_by_finance', False),
                'current_approver_id': req.current_approver_id,
            }
            requests_data.append(request_data)
        
        return Response({
            "employee_id": employee_id,
            "employee_name": employee.fullName,
            "project_identifier": project_identifier,
            "period": period,
            "total_requests": len(all_requests),
            "total_amount": round(total_amount, 2),
            "pending_requests": pending_requests,
            "verified_requests": verified_requests,
            "reimbursement_count": len(project_reimbursements),
            "advance_count": len(project_advances),
            "requests": requests_data
        })
class FinanceVerificationCSVReportView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        """
        Generate CSV report for Finance Verification - NEW ENDPOINT
        """
        if request.user.role != "Finance Verification":
            return Response(
                {"detail": "Access denied. Finance Verification role required."}, 
                status=status.HTTP_403_FORBIDDEN
            )
        
        report_type = request.GET.get('report_type', 'verified')  # verified, pending, all
        period = request.GET.get('period', '1_month')
        finance_user_id = request.user.employee_id
        
        # Calculate date range
        today = timezone.now().date()
        if period == '1_month':
            start_date = today - timedelta(days=30)
        elif period == '3_months':
            start_date = today - timedelta(days=90)
        elif period == '6_months':
            start_date = today - timedelta(days=180)
        else:  # all_time
            start_date = today - timedelta(days=365*5)
        
        # Get data based on report type
        if report_type == 'verified':
            # Get requests verified by this finance user
            approvals = ApprovalHistory.objects.filter(
                approver_id=finance_user_id,
                timestamp__gte=start_date
            )
            requests_data = self._get_requests_from_approvals(approvals, request)
            
        elif report_type == 'pending':
            # Get pending requests assigned to this finance user
            reimbursement_pending = Reimbursement.objects.filter(
                current_approver_id=finance_user_id,
                status="Pending",
                created_at__gte=start_date
            ).select_related('employee')
            
            advance_pending = AdvanceRequest.objects.filter(
                current_approver_id=finance_user_id,
                status="Pending",
                created_at__gte=start_date
            ).select_related('employee')
            
            requests_data = self._format_pending_requests(
                list(reimbursement_pending) + list(advance_pending), 
                request
            )
        else:  # all
            # Combine verified and pending
            approvals = ApprovalHistory.objects.filter(
                approver_id=finance_user_id,
                timestamp__gte=start_date
            )
            verified_data = self._get_requests_from_approvals(approvals, request)
            
            reimbursement_pending = Reimbursement.objects.filter(
                current_approver_id=finance_user_id,
                status="Pending",
                created_at__gte=start_date
            ).select_related('employee')
            
            advance_pending = AdvanceRequest.objects.filter(
                current_approver_id=finance_user_id,
                status="Pending",
                created_at__gte=start_date
            ).select_related('employee')
            
            pending_data = self._format_pending_requests(
                list(reimbursement_pending) + list(advance_pending), 
                request
            )
            
            requests_data = verified_data + pending_data
        
        # Create CSV response
        response = HttpResponse(content_type='text/csv')
        response['Content-Disposition'] = f'attachment; filename="finance_verification_report_{report_type}_{period}_{today}.csv"'
        
        writer = csv.writer(response)
        writer.writerow([
            'Request ID', 'Employee ID', 'Employee Name', 'Request Type',
            'Amount', 'Status', 'Submission Date', 'Verification Date',
            'Project ID', 'Project Name', 'Description', 'Finance Action',
            'Processing Time (Hours)'
        ])
        
        for req in requests_data:
            writer.writerow([
                req['id'],
                req['employee_id'],
                req['employee_name'],
                req['request_type'],
                f"₹{req['amount']}",
                req['status'],
                req['submitted_date'],
                req.get('verification_date', 'N/A'),
                req.get('project_id', 'N/A'),
                req.get('project_name', 'N/A'),
                req['description'][:100] if req['description'] else 'No description',  # Truncate long descriptions
                req.get('finance_action', 'pending'),
                req.get('processing_time', 'N/A')
            ])
        
        return response
    
    def _get_requests_from_approvals(self, approvals, request):
        """Extract request data from approval history"""
        requests_data = []
        
        for approval in approvals:
            try:
                if approval.request_type == 'reimbursement':
                    req_obj = Reimbursement.objects.get(id=approval.request_id)
                    project_name = getattr(req_obj, 'project_name', None)
                else:
                    req_obj = AdvanceRequest.objects.get(id=approval.request_id)
                    project_name = req_obj.project_name
                
                # Calculate processing time
                processing_time = ''
                if req_obj.created_at and approval.timestamp:
                    time_diff = approval.timestamp - req_obj.created_at
                    processing_time = round(time_diff.total_seconds() / 3600, 1)
                
                request_data = {
                    'id': req_obj.id,
                    'employee_id': req_obj.employee.employee_id,
                    'employee_name': req_obj.employee.fullName,
                    'employee_avatar': request.build_absolute_uri(req_obj.employee.avatar.url) if req_obj.employee.avatar else None,
                    'amount': float(req_obj.amount),
                    'description': req_obj.description,
                    'request_type': approval.request_type,
                    'status': req_obj.status,
                    'submitted_date': req_obj.created_at.strftime('%Y-%m-%d %H:%M') if req_obj.created_at else 'N/A',
                    'verification_date': approval.timestamp.strftime('%Y-%m-%d %H:%M') if approval.timestamp else 'N/A',
                    'project_id': req_obj.project_id,
                    'project_name': project_name,
                    'finance_action': approval.action,
                    'processing_time': processing_time,
                }
                
                requests_data.append(request_data)
                
            except (Reimbursement.DoesNotExist, AdvanceRequest.DoesNotExist):
                continue
        
        return requests_data
    
    def _format_pending_requests(self, pending_requests, request):
        """Format pending requests data"""
        requests_data = []
        
        for req in pending_requests:
            is_reimbursement = hasattr(req, 'date')
            
            request_data = {
                'id': req.id,
                'employee_id': req.employee.employee_id,
                'employee_name': req.employee.fullName,
                'employee_avatar': request.build_absolute_uri(req.employee.avatar.url) if req.employee.avatar else None,
                'amount': float(req.amount),
                'description': req.description,
                'request_type': 'reimbursement' if is_reimbursement else 'advance',
                'status': 'Pending',
                'submitted_date': req.created_at.strftime('%Y-%m-%d %H:%M') if req.created_at else 'N/A',
                'verification_date': 'N/A',
                'project_id': req.project_id,
                'project_name': getattr(req, 'project_name', None),
                'finance_action': 'pending',
                'processing_time': 'N/A',
            }
            
            requests_data.append(request_data)
        
        return requests_data
    
class CEOCSVReportView(APIView):
    """Generate CSV reports for CEO dashboard"""
    
    def post(self, request):
        try:
            employee = request.user.employee
            if employee.department.lower() != 'ceo':
                return Response({'error': 'Unauthorized access'}, status=status.HTTP_403_FORBIDDEN)

            report_type = request.data.get('report_type', 'employee')
            period = request.data.get('period', '1_month')
            identifier = request.data.get('identifier', '')
            
            if not identifier:
                return Response({'error': 'Identifier required'}, status=status.HTTP_400_BAD_REQUEST)

            # Calculate date range
            end_date = timezone.now().date()
            if period == '1_month':
                start_date = end_date - timedelta(days=30)
            elif period == '3_months':
                start_date = end_date - timedelta(days=90)
            elif period == '6_months':
                start_date = end_date - timedelta(days=180)
            else:  # all_time
                start_date = end_date - timedelta(days=365*5)

            # Get all requests (both reimbursements and advances)
            reimbursements = Reimbursement.objects.filter(
                Q(status='pending_ceo') | Q(status='approved') | Q(status='rejected'),
                created_at__date__gte=start_date
            ).select_related('employee')
            
            advances = AdvanceRequest.objects.filter(
                Q(status='pending_ceo') | Q(status='approved') | Q(status='rejected'),
                created_at__date__gte=start_date
            ).select_related('employee')

            # Filter based on report type
            if report_type == 'employee':
                reimbursements = reimbursements.filter(employee__employee_id__icontains=identifier)
                advances = advances.filter(employee__employee_id__icontains=identifier)
            else:  # project
                reimbursements = reimbursements.filter(
                    Q(project_id__icontains=identifier) |
                    Q(project_name__icontains=identifier)
                )
                advances = advances.filter(
                    Q(project_id__icontains=identifier) |
                    Q(project_name__icontains=identifier)
                )

            # Create CSV response
            response = HttpResponse(content_type='text/csv')
            response['Content-Disposition'] = f'attachment; filename="ceo_report_{timezone.now().strftime("%Y%m%d_%H%M%S")}.csv"'
            
            writer = csv.writer(response)
            writer.writerow([
                'Request ID', 'Employee ID', 'Employee Name', 'Request Type', 
                'Amount', 'Description', 'Submission Date', 'Status', 'CEO Action',
                'Project ID', 'Project Name', 'Rejection Reason'
            ])

            # Add reimbursement data
            for reimbursement in reimbursements:
                writer.writerow([
                    reimbursement.id,
                    reimbursement.employee.employee_id,
                    reimbursement.employee.fullName,  # Fixed: use fullName instead of name
                    'Reimbursement',
                    reimbursement.amount,
                    reimbursement.description,
                    reimbursement.created_at.strftime('%Y-%m-%d') if reimbursement.created_at else '',
                    reimbursement.status,
                    'Approved' if reimbursement.status == 'approved' else 'Rejected' if reimbursement.status == 'rejected' else 'Pending',
                    reimbursement.project_id or '',
                    getattr(reimbursement, 'project_name', ''),
                    getattr(reimbursement, 'rejection_reason', '')
                ])

            # Add advance data
            for advance in advances:
                writer.writerow([
                    advance.id,
                    advance.employee.employee_id,
                    advance.employee.fullName,  # Fixed: use fullName instead of name
                    'Advance',
                    advance.amount,
                    advance.description,
                    advance.created_at.strftime('%Y-%m-%d') if advance.created_at else '',
                    advance.status,
                    'Approved' if advance.status == 'approved' else 'Rejected' if advance.status == 'rejected' else 'Pending',
                    advance.project_id or '',
                    getattr(advance, 'project_name', ''),
                    getattr(advance, 'rejection_reason', '')
                ])

            return response

        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
class CEOEmployeeProjectReportView(APIView):
    """Generate employee-project specific reports for CEO"""
    
    def post(self, request):
        try:
            employee = request.user.employee
            if employee.department.lower() != 'ceo':
                return Response({'error': 'Unauthorized access'}, status=status.HTTP_403_FORBIDDEN)

            employee_id = request.data.get('employee_id', '')
            project_identifier = request.data.get('project_identifier', '')
            period = request.data.get('period', '1_month')
            
            if not employee_id or not project_identifier:
                return Response({'error': 'Employee ID and Project Identifier required'}, 
                              status=status.HTTP_400_BAD_REQUEST)

            # Calculate date range
            end_date = datetime.now()
            if period == '1_month':
                start_date = end_date - timedelta(days=30)
            elif period == '3_months':
                start_date = end_date - timedelta(days=90)
            elif period == '6_months':
                start_date = end_date - timedelta(days=180)
            else:  # all_time
                start_date = datetime(2000, 1, 1)

            # Get employee
            try:
                emp = Employee.objects.get(employee_id__icontains=employee_id)
            except Employee.DoesNotExist:
                return Response({'error': 'Employee not found'}, status=status.HTTP_404_NOT_FOUND)

            # Get requests for this employee and project
            reimbursements = Reimbursement.objects.filter(
                employee=emp,
                submitted_date__gte=start_date
            ).filter(
                Q(project__project_id__icontains=project_identifier) |
                Q(project__project_name__icontains=project_identifier) |
                Q(project__project_code__icontains=project_identifier)
            ).select_related('project')
            
            advances = AdvanceRequest.objects.filter(
                employee=emp,
                submitted_date__gte=start_date
            ).filter(
                Q(project__project_id__icontains=project_identifier) |
                Q(project__project_name__icontains=project_identifier) |
                Q(project__project_code__icontains=project_identifier)
            ).select_related('project')

            # Prepare response data
            total_requests = reimbursements.count() + advances.count()
            total_amount = sum(r.amount for r in reimbursements) + sum(a.amount for a in advances)
            
            reimbursement_count = reimbursements.count()
            advance_count = advances.count()
            
            approved_count = (reimbursements.filter(status='approved').count() + 
                            advances.filter(status='approved').count())
            rejected_count = (reimbursements.filter(status='rejected').count() + 
                            advances.filter(status='rejected').count())
            pending_count = (reimbursements.filter(status='pending_ceo').count() + 
                           advances.filter(status='pending_ceo').count())

            # Create detailed requests list
            requests_data = []
            for reimbursement in reimbursements:
                requests_data.append({
                    'id': reimbursement.id,
                    'request_type': 'reimbursement',
                    'amount': reimbursement.amount,
                    'description': reimbursement.description,
                    'status': reimbursement.status,
                    'submitted_date': reimbursement.submitted_date.strftime('%Y-%m-%d') if reimbursement.submitted_date else '',
                    'approved_date': reimbursement.approved_date.strftime('%Y-%m-%d') if reimbursement.approved_date else '',
                    'project_id': reimbursement.project.project_id if reimbursement.project else '',
                    'project_name': reimbursement.project.project_name if reimbursement.project else '',
                })
            
            for advance in advances:
                requests_data.append({
                    'id': advance.id,
                    'request_type': 'advance',
                    'amount': advance.amount,
                    'description': advance.description,
                    'status': advance.status,
                    'submitted_date': advance.submitted_date.strftime('%Y-%m-%d') if advance.submitted_date else '',
                    'approved_date': advance.approved_date.strftime('%Y-%m-%d') if advance.approved_date else '',
                    'project_id': advance.project.project_id if advance.project else '',
                    'project_name': advance.project.project_name if advance.project else '',
                })

            response_data = {
                'employee_id': emp.employee_id,
                'employee_name': emp.name,
                'project_identifier': project_identifier,
                'total_requests': total_requests,
                'total_amount': total_amount,
                'reimbursement_count': reimbursement_count,
                'advance_count': advance_count,
                'approved_count': approved_count,
                'rejected_count': rejected_count,
                'pending_count': pending_count,
                'requests': requests_data
            }

            return Response(response_data)

        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
# ==============================
# HR APPROVAL APIS - ADD THESE
# ==============================
class HRPendingApprovalsView(APIView):
    """Get all advance requests pending HR approval"""
    authentication_classes = [TokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        try:
            # Only HR users can access this
            if request.user.role != 'HR':
                return Response(
                    {'error': 'HR access required'}, 
                    status=status.HTTP_403_FORBIDDEN
                )
            
            # Get advance requests where current approver is HR and status is Pending
            pending_requests = AdvanceRequest.objects.filter(
                current_approver_id=request.user.employee_id,
                status='Pending'
            ).select_related('employee')
            
            requests_data = []
            for req in pending_requests:
                requests_data.append({
                    'id': req.id,
                    'employee_id': req.employee.employee_id,
                    'employee_name': req.employee.fullName,
                    'amount': str(req.amount),
                    'purpose': req.description or 'Not specified',
                    'request_date': req.request_date.isoformat() if req.request_date else None,
                    'project_date': req.project_date.isoformat() if req.project_date else None,
                    'created_at': req.created_at.isoformat() if req.created_at else None,
                    'current_step': req.currentStep,
                    'project_id': req.project_id,
                    'project_name': req.project_name,
                })
            
            # ✅ FIXED: Remove safe=False parameter
            return Response(requests_data, status=status.HTTP_200_OK)
            
        except Exception as e:
            print(f"❌ HR Pending Approvals Error: {str(e)}")
            return Response(
                {'error': f'Failed to fetch HR pending approvals: {str(e)}'}, 
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
class HRApproveRequestView(APIView):
    """HR approves an advance request"""
    authentication_classes = [TokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, request_id):
        try:
            # Only HR users can approve
            if request.user.role != 'HR':
                return Response(
                    {'error': 'HR access required'}, 
                    status=status.HTTP_403_FORBIDDEN
                )
            
            # Get the advance request
            try:
                advance_request = AdvanceRequest.objects.get(id=request_id)
            except AdvanceRequest.DoesNotExist:
                return Response(
                    {'error': 'Advance request not found'}, 
                    status=status.HTTP_404_NOT_FOUND
                )
            
            # Check if current user is the approver
            if advance_request.current_approver_id != request.user.employee_id:
                return Response(
                    {'error': 'Not authorized to approve this request'}, 
                    status=status.HTTP_403_FORBIDDEN
                )
            
            # Process HR approval
            process_approval(advance_request, request.user, approved=True)
            
            return Response({
                'message': 'Advance request approved by HR successfully',
                'status': advance_request.status
            })
            
        except Exception as e:
            print(f"❌ HR Approve Error: {str(e)}")
            return Response(
                {'error': f'Failed to approve request: {str(e)}'}, 
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

class HRRejectRequestView(APIView):
    """HR rejects an advance request"""
    authentication_classes = [TokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, request_id):
        try:
            # Only HR users can reject
            if request.user.role != 'HR':
                return Response(
                    {'error': 'HR access required'}, 
                    status=status.HTTP_403_FORBIDDEN
                )
            
            rejection_reason = request.data.get('rejection_reason', '')
            if not rejection_reason:
                return Response(
                    {'error': 'rejection_reason is required'}, 
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            # Get the advance request
            try:
                advance_request = AdvanceRequest.objects.get(id=request_id)
            except AdvanceRequest.DoesNotExist:
                return Response(
                    {'error': 'Advance request not found'}, 
                    status=status.HTTP_404_NOT_FOUND
                )
            
            # Check if current user is the approver
            if advance_request.current_approver_id != request.user.employee_id:
                return Response(
                    {'error': 'Not authorized to reject this request'}, 
                    status=status.HTTP_403_FORBIDDEN
                )
            
            # Process HR rejection
            process_approval(advance_request, request.user, approved=False, rejection_reason=rejection_reason)
            
            return Response({
                'message': 'Advance request rejected by HR',
                'status': advance_request.status
            })
            
        except Exception as e:
            print(f"❌ HR Reject Error: {str(e)}")
            return Response(
                {'error': f'Failed to reject request: {str(e)}'}, 
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
        # Add this method to your HR approval API views
def get_request_details(request, request_id):
    """Get detailed request information for HR view"""
    try:
        advance_request = AdvanceRequest.objects.get(id=request_id)
        
        # Get approval timeline
        approval_history = ApprovalHistory.objects.filter(
            request_type='advance',
            request_id=request_id
        ).order_by('timestamp')
        
        timeline_data = []
        for history in approval_history:
            timeline_data.append({
                'action': history.action,
                'approver_name': history.approver_name,
                'approver_id': history.approver_id,
                'timestamp': history.timestamp.isoformat() if history.timestamp else None,
                'comments': history.comments,
            })
        
        return JsonResponse({
            'success': True,
            'request': {
                'id': advance_request.id,
                'employee_id': advance_request.employee.employee_id,
                'employee_name': advance_request.employee.fullName,
                'amount': str(advance_request.amount),
                'purpose': advance_request.description,
                'request_date': advance_request.request_date.isoformat() if advance_request.request_date else None,
                'project_date': advance_request.project_date.isoformat() if advance_request.project_date else None,
                'status': advance_request.status,
                'current_approver_id': advance_request.current_approver_id,
                'rejection_reason': advance_request.rejection_reason,
                'project_id': advance_request.project_id,
                'project_name': advance_request.project_name,
                'created_at': advance_request.created_at.isoformat() if advance_request.created_at else None,
                'updated_at': advance_request.updated_at.isoformat() if advance_request.updated_at else None,
            },
            'attachments': advance_request.attachments if advance_request.attachments else [],
            'approval_timeline': timeline_data,
            'payments': advance_request.payments if advance_request.payments else [],
        })
        
    except AdvanceRequest.DoesNotExist:
        return JsonResponse({'success': False, 'error': 'Request not found'}, status=404)
    except Exception as e:
        return JsonResponse({'success': False, 'error': str(e)}, status=500)