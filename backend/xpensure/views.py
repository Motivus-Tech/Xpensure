from django.shortcuts import render
from django.http import JsonResponse

# Existing some_view
def some_view(request):
    data = {
        "message": "This is your API response from some_endpoint!"
    }
    return JsonResponse(data)

# Add these for API views
from rest_framework import generics
from .models import Employee
from .serializers import EmployeeSerializer

class EmployeeListCreateView(generics.ListCreateAPIView):
    queryset = Employee.objects.all()
    serializer_class = EmployeeSerializer

class EmployeeDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = Employee.objects.all()
    serializer_class = EmployeeSerializer