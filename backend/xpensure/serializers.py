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
            'phone_number', 'aadhar_card', 'report_to','password', 'confirm_password', 'avatar'
        ]

    def validate(self, attrs):
        if attrs['password'] != attrs['confirm_password']:
            raise serializers.ValidationError({"password": "Passwords do not match"})
        return attrs

    def create(self, validated_data):
        validated_data.pop('confirm_password')
        fullName = validated_data.pop('fullName')
        password = validated_data.pop('password')
        avatar = validated_data.pop('avatar', None)
       

        employee = Employee(**validated_data)
        employee.fullName = fullName 
        if avatar:
            employee.avatar = avatar
           # Important: HR-created employees don’t set password yet
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

# -----------------------------
# Employee Profile Serializer
# -----------------------------
class EmployeeProfileSerializer(serializers.ModelSerializer):
    avatar = serializers.ImageField(required=False, allow_null=True)

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
            "report_to",
            "role",
        ]
        read_only_fields = ["employee_id", "email"]

    def to_representation(self, instance):
        """
        Override to return absolute URL for avatar if available.
        """
        data = super().to_representation(instance)
        request = self.context.get("request")
        avatar = data.get("avatar")
        if avatar:
            try:
                url = instance.avatar.url
                if request is not None:
                    data["avatar"] = request.build_absolute_uri(url)
                else:
                    data["avatar"] = url
            except Exception:
                data["avatar"] = None
        else:
            data["avatar"] = None
        return data
    # -----------------------------
# Employee HR Create Serializer
# -----------------------------
class EmployeeHRCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Employee
        fields = [
            'employee_id', 'email', 'fullName', 'department',
            'phone_number', 'aadhar_card', 'report_to', 'avatar', 'role'
        ]
def create(self, validated_data):
    validated_data['username'] = validated_data.get('employee_id')
    fullName = validated_data.pop('fullName', None)
    employee = Employee(**validated_data)
    if fullName:
        employee.fullName = fullName
    employee.save()
    return employee

