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
        fullName = validated_data.pop('fullName')
        password = validated_data.pop('password')
        validated_data['username'] = validated_data['employee_id']
        employee = Employee(**validated_data)
        employee.fullName = fullName
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
from rest_framework import serializers
from .models import Employee

class EmployeeProfileSerializer(serializers.ModelSerializer):
    # Return absolute URL for profile_photo in representation
    profile_photo = serializers.ImageField(required=False, allow_null=True)

    class Meta:
        model = Employee
        
        fields = [
            "employee_id",
            "email",
            "fullName",        
            "department",
            "phone_number",
            "aadhar_card",
            "avatar",
        ]
        read_only_fields = ["employee_id", "email"]

    def to_representation(self, instance):
        data = super().to_representation(instance)
        request = self.context.get("request")
        photo = data.get("profile_photo")
        # build absolute URL if present
        if photo:
            try:
                # instance.profile_photo.url may cause ValueError if file missing
                url = instance.profile_photo.url
                if request is not None:
                    data["avatar"] = request.build_absolute_uri(url)
                else:
                    data["avatar"] = url
            except Exception:
                data["avatar"] = None
        else:
            data["avatar"] = None
        return data
