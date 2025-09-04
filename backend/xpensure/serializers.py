from rest_framework import serializers
from .models import Employee, Reimbursement, AdvanceRequest

# -----------------------------
# Employee Signup Serializer
# -----------------------------
from rest_framework import serializers
from .models import Employee, Reimbursement, AdvanceRequest

class EmployeeSignupSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, required=True, min_length=6)
    confirm_password = serializers.CharField(write_only=True, required=True, min_length=6)
    fullName = serializers.CharField(required=False)
    avatar = serializers.ImageField(required=False, allow_null=True)

    class Meta:
        model = Employee
        fields = [
            'employee_id', 'email', 'fullName', 'department',
            'phone_number', 'aadhar_card', 'password', 'confirm_password', 'avatar'
        ]
        extra_kwargs = {
            'employee_id': {'validators': []},  # bypass unique validator
            'email': {'validators': []},        # bypass unique validator
        }

    def validate(self, attrs):
        # Password match check
        if attrs['password'] != attrs['confirm_password']:
            raise serializers.ValidationError({"password": "Passwords do not match"})

        # Check if employee exists in DB (added by HR)
        try:
            self.employee = Employee.objects.get(
                employee_id=attrs['employee_id'],
                email=attrs['email']
            )
        except Employee.DoesNotExist:
            raise serializers.ValidationError({"detail": "Employee details not found. Please contact HR."})

        # Prevent multiple signups
        if self.hr_employee.has_usable_password():
            raise serializers.ValidationError({"detail": "Employee has already signed up."})

        return attrs

    def create(self, validated_data):
        validated_data.pop('confirm_password')
        password = validated_data.pop('password')
        avatar = validated_data.pop('avatar', None)

        # Update existing HR-created employee
        employee = self.hr_employee
        employee.fullName = validated_data.get('fullName', employee.fullName)
        employee.department = validated_data.get('department', employee.department)
        employee.phone_number = validated_data.get('phone_number', employee.phone_number)
        employee.aadhar_card = validated_data.get('aadhar_card', employee.aadhar_card)
        if avatar:
            employee.avatar = avatar

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
        ]
        read_only_fields = ["employee_id", "email"]

    def to_representation(self, instance):
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
# HR/Admin Employee Serializer (no password)
# -----------------------------
class EmployeeHRCreateSerializer(serializers.ModelSerializer):
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
            "role",
            "is_active",
            "is_staff",
            "report_to",
        ]
