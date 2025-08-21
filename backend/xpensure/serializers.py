from rest_framework import serializers
from .models import Employee

class EmployeeSignupSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, required=True, min_length=6)
    confirm_password = serializers.CharField(write_only=True, required=True, min_length=6)
    fullName = serializers.CharField(write_only=True)  # Only for input

    class Meta:
        model = Employee
        fields = [
            'employee_id',
            'email',
            'fullName',       
            'department',
            'phone_number',
            'aadhar_card',
            'password',
            'confirm_password',
        ]

    def validate(self, attrs):
        if attrs['password'] != attrs['confirm_password']:
            raise serializers.ValidationError({"password": "Passwords do not match"})
        return attrs

    def create(self, validated_data):
        # Pop fields not in the model
        validated_data.pop('confirm_password')
        full_name = validated_data.pop('fullName')  # get fullName from frontend

        # Set username equal to employee_id
        validated_data['username'] = validated_data['employee_id']

        # Extract password
        password = validated_data.pop('password')

        # Create employee instance correctly
        employee = Employee(**validated_data)
        employee.full_name = full_name  # assign full_name manually
        employee.set_password(password)
        employee.save()
        return employee
