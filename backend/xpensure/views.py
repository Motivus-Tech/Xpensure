from rest_framework import status, permissions, generics, viewsets
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.authtoken.models import Token
from django.contrib.auth import get_user_model
from .serializers import EmployeeSignupSerializer, ReimbursementSerializer, AdvanceRequestSerializer
from .models import Reimbursement, AdvanceRequest

User = get_user_model()

# -----------------------------
# Employee Signup
# -----------------------------
class EmployeeSignupView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        data = request.data.copy()
        if 'fullName' in data:
            data['fullName'] = data.pop('fullName')
        serializer = EmployeeSignupSerializer(data=data)
        if serializer.is_valid():
            employee = serializer.save()
            token, _ = Token.objects.get_or_create(user=employee)
            return Response({
                'employee_id': employee.employee_id,
                'email': employee.email,
                'fullName': employee.fullName,
                'department': employee.department,
                'phone_number': employee.phone_number,
                'aadhar_card': employee.aadhar_card,
                'token': token.key
            }, status=status.HTTP_201_CREATED)
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
            return Response({'error': 'Both employee_id and password are required'}, status=status.HTTP_400_BAD_REQUEST)
        try:
            user = User.objects.get(employee_id=employee_id)
        except User.DoesNotExist:
            return Response({'error': 'Invalid credentials'}, status=status.HTTP_401_UNAUTHORIZED)
        if user.check_password(password):
            token, _ = Token.objects.get_or_create(user=user)
            return Response({
                'employee_id': user.employee_id,
                'email': user.email,
                'fullName': user.fullName,
                'department': user.department,
                'phone_number': user.phone_number,
                'aadhar_card': user.aadhar_card,
                'token': token.key
            })
        return Response({'error': 'Invalid credentials'}, status=status.HTTP_401_UNAUTHORIZED)


# -----------------------------
# Admin-only employee list/create
# -----------------------------
class EmployeeListCreateView(generics.ListCreateAPIView):
    queryset = User.objects.all()
    serializer_class = EmployeeSignupSerializer
    permission_classes = [permissions.IsAdminUser]


# -----------------------------
# Admin-only employee detail
# -----------------------------
class EmployeeDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = User.objects.all()
    serializer_class = EmployeeSignupSerializer
    lookup_field = 'employee_id'
    permission_classes = [permissions.IsAdminUser]


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
        
# Reimbursements API
class ReimbursementListCreateView(generics.ListCreateAPIView):
    serializer_class = ReimbursementSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        # Only return reimbursements for the logged-in user
        return Reimbursement.objects.filter(employee=self.request.user)

    def perform_create(self, serializer):
        # Assign the logged-in user as the employee
        serializer.save(employee=self.request.user)


# Advance Requests API
class AdvanceRequestListCreateView(generics.ListCreateAPIView):
    serializer_class = AdvanceRequestSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        # Only return advances for the logged-in user
        return AdvanceRequest.objects.filter(employee=self.request.user)

    def perform_create(self, serializer):
        # Assign the logged-in user as the employee
        serializer.save(employee=self.request.user)