from rest_framework import status, permissions, generics, viewsets
from rest_framework.response import Response
from rest_framework.views import APIView
from .models import Employee
from rest_framework.authtoken.models import Token
from django.contrib.auth import get_user_model
from .serializers import (
    EmployeeSignupSerializer,
    ReimbursementSerializer,
    AdvanceRequestSerializer,
    EmployeeProfileSerializer,
    EmployeeHRCreateSerializer
)
from .models import Reimbursement, AdvanceRequest
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.authentication import TokenAuthentication

User = get_user_model()

# -----------------------------
# Employee Signup (Self signup)
# -----------------------------
class EmployeeSignupView(APIView):
    permission_classes = [permissions.AllowAny]
    parser_classes = [MultiPartParser, FormParser]

    def post(self, request):
        serializer = EmployeeSignupSerializer(data=request.data)
        if serializer.is_valid():
            employee = serializer.save()  # Updates existing HR row

            token, _ = Token.objects.get_or_create(user=employee)

            response_data = {
                'employee_id': employee.employee_id,
                'email': employee.email,
                'fullName': employee.fullName,
                'department': employee.department,
                'phone_number': employee.phone_number,
                'aadhar_card': employee.aadhar_card,
                'avatar': request.build_absolute_uri(employee.avatar.url) if employee.avatar else None,
                'token': token.key
            }
            return Response(response_data, status=status.HTTP_201_CREATED)

        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

# -----------------------------
# Employee Login
# -----------------------------
class EmployeeLoginView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        employee_id = request.data.get('employee_id')
        password = request.data.get('password')

        if not employee_id or not password:
            return Response({'success': False, 'message': 'Both employee_id and password are required'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            user = User.objects.get(employee_id=employee_id)
        except User.DoesNotExist:
            return Response({'success': False, 'message': 'Invalid credentials'}, status=status.HTTP_401_UNAUTHORIZED)

        if user.check_password(password):
            token, _ = Token.objects.get_or_create(user=user)
            return Response({
                'success': True,
                'employee_id': user.employee_id,
                'fullName': user.fullName,
                'email': user.email,
                'department': user.department,
                'phone_number': user.phone_number,
                'aadhar_card': user.aadhar_card,
                'avatar': request.build_absolute_uri(user.avatar.url) if user.avatar and user.avatar.url else None,
                'role': user.role,
                'token': token.key
            })
        else:
            return Response({'success': False, 'message': 'Invalid credentials'}, status=status.HTTP_401_UNAUTHORIZED)


# -----------------------------
# Admin-only employee list/create
# -----------------------------
class EmployeeListCreateView(generics.ListCreateAPIView):
    queryset = User.objects.all()
    serializer_class = EmployeeHRCreateSerializer  # HR serializer (no password required)
    authentication_classes = [TokenAuthentication]
    permission_classes = [permissions.IsAdminUser]


# -----------------------------
# Admin-only employee detail
# -----------------------------
class EmployeeDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = User.objects.all()
    serializer_class = EmployeeHRCreateSerializer  # HR serializer
    lookup_field = 'employee_id'
    authentication_classes = [TokenAuthentication] 
    permission_classes = [permissions.IsAdminUser]

    def put(self, request, *args, **kwargs):
        emp = self.get_object()
        # If password field is sent, set it properly
        new_password = request.data.get("password")
        if new_password:
            emp.set_password(new_password)
            emp.save()
            # Remove password from request data so serializer doesn't complain
            request.data._mutable = True
            request.data.pop("password")
        return super().put(request, *args, **kwargs)


# -----------------------------
# Reimbursement ViewSet
# -----------------------------
class ReimbursementViewSet(viewsets.ModelViewSet):
    serializer_class = ReimbursementSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Reimbursement.objects.filter(employee=self.request.user).order_by('-date')

    def perform_create(self, serializer):
        serializer.save(employee=self.request.user)


# -----------------------------
# Advance Request ViewSet
# -----------------------------
class AdvanceRequestViewSet(viewsets.ModelViewSet):
    serializer_class = AdvanceRequestSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return AdvanceRequest.objects.filter(employee=self.request.user).order_by('-request_date')

    def perform_create(self, serializer):
        serializer.save(employee=self.request.user)


# -----------------------------
# Reimbursement API
# -----------------------------
class ReimbursementListCreateView(generics.ListCreateAPIView):
    serializer_class = ReimbursementSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Reimbursement.objects.filter(employee=self.request.user)

    def perform_create(self, serializer):
        serializer.save(employee=self.request.user)


# -----------------------------
# Advance Requests API
# -----------------------------
class AdvanceRequestListCreateView(generics.ListCreateAPIView):
    serializer_class = AdvanceRequestSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return AdvanceRequest.objects.filter(employee=self.request.user)

    def perform_create(self, serializer):
        serializer.save(employee=self.request.user)


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
# Verify Password
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


# -----------------------------
# Change Password
# -----------------------------
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

        old_password = request.data.get("old_password")
        new_password = request.data.get("new_password")

        if not old_password or not new_password:
            return Response({"detail": "old_password and new_password are required."}, status=status.HTTP_400_BAD_REQUEST)

        if not user.check_password(old_password):
            return Response({"detail": "Incorrect old password."}, status=status.HTTP_401_UNAUTHORIZED)

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
