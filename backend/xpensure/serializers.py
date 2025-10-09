from rest_framework import serializers
from .models import Employee, Reimbursement, AdvanceRequest

# -----------------------------
# Employee Signup Serializer
# -----------------------------
class EmployeeSignupSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, required=True, min_length=6)
    confirm_password = serializers.CharField(write_only=True, required=True, min_length=6)
    fullName = serializers.CharField(required=False)
    avatar = serializers.ImageField(required=False, allow_null=True)

    class Meta:
        model = Employee
        fields = [
            'employee_id', 'email', 'fullName', 'department',
            'phone_number', 'aadhar_card', 
            'password', 'confirm_password', 'avatar'
        ]
        extra_kwargs = {
            'employee_id': {'validators': []},
            'email': {'validators': []},
        }

    def validate(self, attrs):
        if attrs['password'] != attrs['confirm_password']:
            raise serializers.ValidationError({"password": "Passwords do not match"})

        # Get employee record from DB (HR-created)
        try:
            self.hr_employee = Employee.objects.get(
                employee_id=attrs['employee_id'],
                email__iexact=attrs['email']
            )
        except Employee.DoesNotExist:
            raise serializers.ValidationError({"detail": "Employee details not found. Please contact HR."})

        # Validate key fields
        mismatches = []
        if self.hr_employee.fullName.lower() != attrs.get('fullName', '').lower():
            mismatches.append("fullName")
        if self.hr_employee.department.lower() != attrs.get('department', '').lower():
            mismatches.append("department")
        if self.hr_employee.phone_number != attrs.get('phone_number', ''):
            mismatches.append("phone_number")
        if self.hr_employee.aadhar_card != attrs.get('aadhar_card', ''):
            mismatches.append("aadhar_card")

        if mismatches:
            raise serializers.ValidationError({"detail": f"Employee data mismatch on: {', '.join(mismatches)}. Please contact HR."})

        return attrs

    def create(self, validated_data):
        validated_data.pop('confirm_password')
        password = validated_data.pop('password')
        avatar = validated_data.pop('avatar', None)

        employee = self.hr_employee
        employee.fullName = validated_data.get('fullName', employee.fullName)
        employee.department = validated_data.get('department', employee.department)
        employee.phone_number = validated_data.get('phone_number', employee.phone_number)
        employee.aadhar_card = validated_data.get('aadhar_card', employee.aadhar_card)
        if avatar:
            employee.avatar = avatar

        # Set password and save
        employee.set_password(password)
        employee.save(update_fields=['password'])  # ensure password is written immediately
        employee.refresh_from_db()  # refresh object from DB

        return employee

class ReimbursementSerializer(serializers.ModelSerializer):
    employee_id = serializers.CharField(source="employee.employee_id", read_only=True)
    

    class Meta:
        model = Reimbursement
        fields = [
            'id', 'employee_id', 'amount', 'description', 'attachment', 
            'date', 'status', 'currentStep', 'current_approver_id', 
            'rejection_reason', 'payments', 'created_at', 'updated_at',
            'payment_date', 'final_approver', 'approved_by_ceo', 'approved_by_finance'  # ✅ ADDED NEW FIELDS
        ]
        read_only_fields = ['employee', 'employee_id', 'created_at', 'updated_at']


class AdvanceRequestSerializer(serializers.ModelSerializer):
    employee_id = serializers.CharField(source="employee.employee_id", read_only=True)

    class Meta:
        model = AdvanceRequest
        fields = [
            'id', 'employee_id', 'amount', 'description', 'request_date', 
            'project_date', 'attachment', 'status', 'currentStep', 
            'current_approver_id', 'rejection_reason', 'payments', 
            'created_at', 'updated_at', 'payment_date', 'final_approver', 
            'approved_by_ceo', 'approved_by_finance'  # ✅ ADDED NEW FIELDS
        ]
        read_only_fields = ['employee', 'employee_id', 'created_at', 'updated_at']


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

    def create(self, validated_data):
        employee = super().create(validated_data)
        employee.set_unusable_password()  # mark password unusable
        employee.save()
        return employee

    def update(self, instance, validated_data):
        instance = super().update(instance, validated_data)
        return instance