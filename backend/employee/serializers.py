from rest_framework import serializers
from .models import Employee
from django.contrib.auth import authenticate

class EmployeeRegistrationSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)
    confirm_password = serializers.CharField(write_only=True)

    class Meta:
        model = Employee
        fields = ['username', 'employee_id', 'department', 'phone_number', 'email', 'aadhar_card', 'password', 'confirm_password']

    def validate(self, data):
        if data['password'] != data['confirm_password']:
            raise serializers.ValidationError("Passwords do not match.")
        return data

    def create(self, validated_data):
        validated_data.pop('confirm_password')
        password = validated_data.pop('password')
        employee = Employee(**validated_data)
        employee.set_password(password)  # hashes password securely
        employee.save()
        return employee

class EmployeeLoginSerializer(serializers.Serializer):
    employee_id = serializers.CharField()
    password = serializers.CharField(write_only=True)

    def validate(self, data):
        # authenticate expects username, so pass employee_id as username
        employee = authenticate(username=data['employee_id'], password=data['password'])
        if not employee:
            raise serializers.ValidationError("Invalid employee ID or password.")
        data['employee'] = employee
        return data