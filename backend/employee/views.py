from rest_framework import generics, status
from rest_framework.response import Response
from rest_framework.authtoken.models import Token
from rest_framework.permissions import AllowAny
from .serializers import EmployeeRegistrationSerializer, EmployeeLoginSerializer

class EmployeeRegistrationView(generics.CreateAPIView):
    permission_classes = [AllowAny]
    serializer_class = EmployeeRegistrationSerializer
    # POST handled automatically

class EmployeeLoginView(generics.GenericAPIView):
    permission_classes = [AllowAny]
    serializer_class = EmployeeLoginSerializer

    def post(self, request):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        employee = serializer.validated_data['employee']
        token, created = Token.objects.get_or_create(user=employee)
        return Response({"token": token.key}, status=status.HTTP_200_OK)