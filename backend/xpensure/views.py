from rest_framework import status, permissions, generics
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.authtoken.models import Token
from django.contrib.auth import get_user_model
from .serializers import EmployeeSignupSerializer

User = get_user_model()

# -----------------------------
# Signup API
# -----------------------------
class EmployeeSignupView(APIView):
    """
    Handles employee registration
    Frontend does NOT send username; it's auto-generated from employee_id
    """
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = EmployeeSignupSerializer(data=request.data)
        if serializer.is_valid():
            # 1️⃣ Save the employee first
            employee = serializer.save()

            # 2️⃣ Create token safely after employee is saved
            token, created = Token.objects.get_or_create(user=employee)

            # 3️⃣ Return response
            return Response({
                'employee_id': employee.employee_id,
                'email': employee.email,
                'full_name': employee.full_name,
                'department': employee.department,
                'phone_number': employee.phone_number,
                'aadhar_card': employee.aadhar_card,
                'token': token.key
            }, status=status.HTTP_201_CREATED)

        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


# -----------------------------
# Login API
# -----------------------------
class EmployeeLoginView(APIView):
    """
    Handles login via employee_id
    """
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        employee_id = request.data.get('employee_id')
        password = request.data.get('password')

        if not employee_id or not password:
            return Response(
                {'error': 'Both employee_id and password are required'},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            user = User.objects.get(employee_id=employee_id)
        except User.DoesNotExist:
            return Response({'error': 'Invalid credentials'}, status=status.HTTP_401_UNAUTHORIZED)

        if user.check_password(password):
            # Use get_or_create so it never fails
            token, _ = Token.objects.get_or_create(user=user)
            return Response({
                'employee_id': user.employee_id,
                'email': user.email,
                'full_name': user.full_name,
                'department': user.department,
                'phone_number': user.phone_number,
                'aadhar_card': user.aadhar_card,
                'token': token.key
            })
        return Response({'error': 'Invalid credentials'}, status=status.HTTP_401_UNAUTHORIZED)


# -----------------------------
# Optional: List & Create Employees (for admins)
# -----------------------------
class EmployeeListCreateView(generics.ListCreateAPIView):
    queryset = User.objects.all()
    serializer_class = EmployeeSignupSerializer
    permission_classes = [permissions.IsAdminUser]  # restrict list/create to admins


# -----------------------------
# Optional: Retrieve, Update, Delete Employee (for admins)
# -----------------------------
class EmployeeDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = User.objects.all()
    serializer_class = EmployeeSignupSerializer
    lookup_field = 'employee_id'
    permission_classes = [permissions.IsAdminUser]
