from django.shortcuts import render
from django.http import JsonResponse
from rest_framework import generics, status
from rest_framework.response import Response
from rest_framework.views import APIView
from django.contrib.auth import authenticate

from .models import Employee
from .serializers import EmployeeSerializer


# Example API view
def some_view(request):
    data = {
        "message": "This is your API response from some_endpoint!"
    }
    return JsonResponse(data)


# List and Create Employees
class EmployeeListCreateView(generics.ListCreateAPIView):
    queryset = Employee.objects.all()
    serializer_class = EmployeeSerializer


# Retrieve, Update, Delete Employee
class EmployeeDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = Employee.objects.all()
    serializer_class = EmployeeSerializer


# Employee Login View
class EmployeeLoginView(APIView):
    def post(self, request):
        employee_id = request.data.get("employee_id")
        password = request.data.get("password")

        if not employee_id or not password:
            return Response({"error": "Employee ID and password are required"}, status=status.HTTP_400_BAD_REQUEST)

        try:
            employee = Employee.objects.get(employee_id=employee_id)
        except Employee.DoesNotExist:
            return Response({"error": "Invalid employee ID"}, status=status.HTTP_404_NOT_FOUND)

        # Check password (assuming you have password stored as plain text for now; in real case use hashing)
        if employee.password != password:
            return Response({"error": "Invalid password"}, status=status.HTTP_401_UNAUTHORIZED)

        return Response({"message": "Login successful", "employee_id": employee.employee_id, "username": employee.username})
# Employee Signup View
from django.contrib.auth.hashers import make_password

class EmployeeSignupView(APIView):
    def post(self, request):
        data = request.data
        try:
            employee = Employee.objects.create(
                username=data.get("username"),
                employee_id=data.get("employee_id"),
                email=data.get("email"),
                phone_number=data.get("phone_number", ""),
                department=data.get("department", ""),
                aadhar_card=data.get("aadhar_card", ""),
                password=make_password(data.get("password"))  # Hash password
            )
            return Response({"message": "Signup Successful"}, status=status.HTTP_201_CREATED)
        except Exception as e:
            return Response({"error": str(e)}, status=status.HTTP_400_BAD_REQUEST)
