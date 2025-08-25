from rest_framework import serializers
from .models import Employee, Reimbursement, AdvanceRequest

# -----------------------------
# Employee Signup Serializer
# -----------------------------
class EmployeeSignupSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, required=True, min_length=6)
    confirm_password = serializers.CharField(write_only=True, required=True, min_length=6)
    fullName = serializers.CharField(write_only=True)

    class Meta:
        model = Employee
        fields = [
            'employee_id', 'email', 'fullName', 'department',
            'phone_number', 'aadhar_card', 'password', 'confirm_password'
        ]

    def validate(self, attrs):
        if attrs['password'] != attrs['confirm_password']:
            raise serializers.ValidationError({"password": "Passwords do not match"})
        return attrs

    def create(self, validated_data):
        validated_data.pop('confirm_password')
        full_name = validated_data.pop('fullName')
        password = validated_data.pop('password')
        validated_data['username'] = validated_data['employee_id']
        employee = Employee(**validated_data)
        employee.full_name = full_name
        employee.set_password(password)
        employee.save()
        return employee

# -----------------------------
# Reimbursement Serializer
# -----------------------------
class ReimbursementSerializer(serializers.ModelSerializer):
    class Meta:
        model = Reimbursement
        fields = ['id', 'employee', 'amount', 'description', 'attachment', 'date', 'created_at']
        read_only_fields = ['employee', 'created_at']

# -----------------------------
# Advance Request Serializer
# -----------------------------
class AdvanceRequestSerializer(serializers.ModelSerializer):
    class Meta:
        model = AdvanceRequest
        fields = ['id', 'employee', 'amount', 'description', 'request_date', 'project_date', 'attachment', 'created_at']
        read_only_fields = ['employee', 'created_at']
