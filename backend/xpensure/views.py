from rest_framework import generics, status, permissions
from rest_framework.response import Response
from rest_framework.views import APIView
from django.contrib.auth import authenticate
from rest_framework.authtoken.models import Token
from django.contrib.auth.hashers import make_password

from .models import Employee
from .serializers import EmployeeSerializer

class EmployeeListCreateView(generics.ListCreateAPIView):
    """
    Handles listing and creating employees
    """
    queryset = Employee.objects.all()
    serializer_class = EmployeeSerializer
    permission_classes = [permissions.IsAuthenticatedOrReadOnly]

class EmployeeDetailView(generics.RetrieveUpdateDestroyAPIView):
    """
    Handles single employee operations
    """
    queryset = Employee.objects.all()
    serializer_class = EmployeeSerializer
    lookup_field = 'employee_id'
    permission_classes = [permissions.IsAuthenticated]

class EmployeeSignupView(APIView):
    """
    Handles employee registration
    Required fields: username, employee_id, email, password
    """
    def post(self, request):
        serializer = EmployeeSerializer(data=request.data)
        if serializer.is_valid():
            validated_data = serializer.validated_data
            validated_data['password'] = make_password(validated_data['password'])
            
            try:
                employee = Employee.objects.create_user(**validated_data)
                token = Token.objects.create(user=employee)
                return Response({
                    'employee': EmployeeSerializer(employee).data,
                    'token': token.key
                }, status=status.HTTP_201_CREATED)
            except Exception as e:
                return Response(
                    {'error': str(e)},
                    status=status.HTTP_400_BAD_REQUEST
                )
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

class EmployeeLoginView(APIView):
    """
    Handles employee login
    Required fields: username, password
    """
    def post(self, request):
        username = request.data.get('username')
        password = request.data.get('password')

        if not username or not password:
            return Response(
                {'error': 'Both username and password are required'},
                status=status.HTTP_400_BAD_REQUEST
            )

        user = authenticate(username=username, password=password)
        
        if user:
            token, _ = Token.objects.get_or_create(user=user)
            return Response({
                'employee': EmployeeSerializer(user).data,
                'token': token.key
            })
        return Response(
            {'error': 'Invalid credentials'},
            status=status.HTTP_401_UNAUTHORIZED
        )