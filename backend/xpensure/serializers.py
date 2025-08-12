from rest_framework import serializers
from .models import Employee

class EmployeeSerializer(serializers.ModelSerializer):
    class Meta:
        model = Employee
        fields = ['id', 'username', 'employee_id', 'department', 'phone_number', 'aadhar_card', 'email', 'first_name', 'last_name']
