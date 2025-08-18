from rest_framework import serializers
from .models import Employee

class EmployeeSignupSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, required=True)
    confirm_password = serializers.CharField(write_only=True, required=True)

    class Meta:
        model = Employee
        fields = [
            'employee_id',
            'email',
            'first_name',
            'last_name',
            'department',
            'phone_number',
            'aadhar_card',
            'password',
            'confirm_password',
        ]

    def validate(self, attrs):
        if attrs['password'] != attrs['confirm_password']:
            raise serializers.ValidationError("Passwords do not match")
        return attrs

    def create(self, validated_data):
        validated_data.pop('confirm_password')
        # Automatically set username = employee_id
        validated_data['username'] = validated_data['employee_id']
        password = validated_data.pop('password')
        employee = Employee(**validated_data)
        employee.set_password(password)
        employee.save()
        return employee
