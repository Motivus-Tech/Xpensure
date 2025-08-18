from rest_framework import serializers
from .models import Employee

class EmployeeSignupSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, required=True, min_length=6)
    confirm_password = serializers.CharField(write_only=True, required=True, min_length=6)

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
        """
        Ensure password and confirm_password match
        """
        if attrs['password'] != attrs['confirm_password']:
            raise serializers.ValidationError({"password": "Passwords do not match"})
        return attrs

    def create(self, validated_data):
        """
        Create and return a new Employee instance
        """
        # Remove confirm_password from data
        validated_data.pop('confirm_password')

        # Set username equal to employee_id
        validated_data['username'] = validated_data['employee_id']

        # Extract password
        password = validated_data.pop('password')

        # Create employee instance
        employee = Employee(**validated_data)
        employee.set_password(password)  # Hash password
        employee.save()
        return employee


class EmployeeLoginSerializer(serializers.Serializer):
    """
    Optional serializer for login validation
    """
    employee_id = serializers.CharField(required=True)
    password = serializers.CharField(required=True, write_only=True)
