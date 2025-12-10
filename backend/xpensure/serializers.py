
from rest_framework import serializers
from .models import Employee, Reimbursement, AdvanceRequest
import os
import uuid
from django.core.files.storage import default_storage

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

        try:
            self.hr_employee = Employee.objects.get(
                employee_id=attrs['employee_id'],
                email__iexact=attrs['email']
            )
        except Employee.DoesNotExist:
            raise serializers.ValidationError({"detail": "Employee details not found. Please contact HR."})

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

        employee.set_password(password)
        employee.save(update_fields=['password'])
        employee.refresh_from_db()

        return employee
class ReimbursementSerializer(serializers.ModelSerializer):
    employee_id = serializers.CharField(source="employee.employee_id", read_only=True)
    project_id = serializers.CharField(write_only=True, required=False, allow_blank=True)
    
    # ✅ FIXED: Multiple files handling
    attachments = serializers.ListField(
        child=serializers.FileField(
            max_length=100000, 
            allow_empty_file=True, 
            use_url=False,
            write_only=True
        ),
        write_only=True,
        required=False,
        allow_empty=True
    )
    
    # Read-only field to display attachment URLs
    attachment_urls = serializers.SerializerMethodField(read_only=True)
    projectId = serializers.CharField(source="project_id", read_only=True)

    class Meta:
        model = Reimbursement
        fields = [
            'id', 'employee_id', 'amount', 'description', 'attachment', 
            'attachments', 'attachment_urls', 'date', 'status', 'currentStep', 
            'current_approver_id', 'rejection_reason', 'payments', 'created_at', 
            'updated_at', 'payment_date', 'final_approver', 'approved_by_ceo', 
            'approved_by_finance','project_id','projectId' 
        ]
        read_only_fields = ['employee', 'employee_id', 'created_at', 'updated_at']

    # ✅ YEH METHOD CLASS KE ANDAR HONA CHAHIYE (INDENT FIX)
    def get_attachment_urls(self, obj):
        request = self.context.get('request')
        if obj.attachments and isinstance(obj.attachments, list):
            urls = []
            for attachment_path in obj.attachments:
                if attachment_path:
                    try:
                        # Extract filename
                        filename = attachment_path.split('/')[-1]
                        
                        # Check which folder it's from
                        if 'advance_attachments' in attachment_path:
                            folder = 'advance_attachments'
                        elif 'reimbursement_attachments' in attachment_path:
                            folder = 'reimbursement_attachments'
                        elif 'uploads' in attachment_path:
                            folder = 'uploads'
                        else:
                            folder = 'uploads'  # Default
                        
                        # Build URL
                        if request:
                            url = request.build_absolute_uri(f'/media/{folder}/{filename}')
                        else:
                            url = f'/media/{folder}/{filename}'
                        
                        urls.append(url)
                    except Exception as e:
                        urls.append(attachment_path)
            return urls
        return []

    def create(self, validated_data):
        # Extract project_id from validated_data
        project_id = validated_data.pop('project_id', None)
        attachments = validated_data.pop('attachments', [])
        
        # ✅ CREATE WITH PROJECT ID
        reimbursement = Reimbursement.objects.create(
            project_id=project_id,
            **validated_data
        )
        
        # Handle attachments - FIXED: Save paths that can be converted to URLs
        if attachments:
            attachment_paths = []
            for attachment in attachments:
                # ✅ FIXED: Save with proper folder structure
                ext = os.path.splitext(attachment.name)[1]
                filename = f"reimbursement_attachments/reimbursement_{uuid.uuid4()}{ext}"  # ✅ CHANGE ho gaya
                
                # Save file
                saved_path = default_storage.save(filename, attachment)
                
                # ✅ FIXED: Store path that can be converted to URL
                attachment_paths.append(filename)
            
            reimbursement.attachments = attachment_paths
            reimbursement.save()
        
        return reimbursement

    def update(self, instance, validated_data):
        attachments = validated_data.pop('attachments', None)
        
        # Update basic fields
        instance = super().update(instance, validated_data)
        
        # Handle new attachments
        if attachments is not None:
            if instance.attachments is None:
                instance.attachments = []
            
            for attachment in attachments:
                # ✅ FIXED: Consistent naming
                ext = os.path.splitext(attachment.name)[1]
                filename = f"uploads/reimbursement_{uuid.uuid4()}{ext}"
                saved_path = default_storage.save(filename, attachment)
                instance.attachments.append(saved_path)
            
            instance.save()
        
        return instance

class AdvanceRequestSerializer(serializers.ModelSerializer):
    employee_id = serializers.CharField(source="employee.employee_id", read_only=True)
    
    # ✅ ADDED: Project fields
    project_id = serializers.CharField(write_only=True, required=False, allow_blank=True)
    project_name = serializers.CharField(write_only=True, required=False, allow_blank=True)
    
    # Multiple files handling
    attachments = serializers.ListField(
        child=serializers.FileField(
            max_length=100000, 
            allow_empty_file=True, 
            use_url=False,
            write_only=True
        ),
        write_only=True,
        required=False,
        allow_empty=True
    )
    
    # Read-only field to display attachment URLs
    attachment_urls = serializers.SerializerMethodField(read_only=True)
    # ✅ ADD READ-ONLY PROJECT FIELDS FOR RESPONSE
    projectId = serializers.CharField(source="project_id", read_only=True)
    projectName = serializers.CharField(source="project_name", read_only=True)

    class Meta:
        model = AdvanceRequest
        fields = [
            'id', 'employee_id', 'project_id', 'project_name', 'amount', 'description', 
            'request_date', 'project_date', 'attachment', 'attachments', 'attachment_urls', 
            'status', 'currentStep', 'current_approver_id', 'rejection_reason', 'payments', 
            'created_at', 'updated_at', 'payment_date', 'final_approver', 
            'approved_by_ceo', 'approved_by_finance', 'projectId', 'projectName', 
        ]
        read_only_fields = ['employee', 'employee_id', 'created_at', 'updated_at']

    
    def get_attachment_urls(self, obj):
        """Return list of attachment URLs - FIXED VERSION"""
        request = self.context.get('request')
        if obj.attachments and isinstance(obj.attachments, list):
            urls = []
            for attachment_path in obj.attachments:
                if attachment_path:
                    try:
                        # Extract filename
                        filename = attachment_path.split('/')[-1]
                        
                        # Check which folder it's from
                        if 'advance_attachments' in attachment_path:
                            folder = 'advance_attachments'
                        elif 'reimbursement_attachments' in attachment_path:
                            folder = 'reimbursement_attachments'
                        elif 'uploads' in attachment_path:
                            folder = 'uploads'
                        else:
                            folder = 'uploads'  # Default
                        
                        # Build URL
                        if request:
                            url = request.build_absolute_uri(f'/media/{folder}/{filename}')
                        else:
                            url = f'/media/{folder}/{filename}'
                        
                        urls.append(url)
                    except Exception as e:
                        # Fallback to original path
                        print(f"Error generating URL for {attachment_path}: {e}")
                        urls.append(attachment_path)
            return urls
        return []

    def create(self, validated_data):
        # Extract project fields
        project_id = validated_data.pop('project_id', None)
        project_name = validated_data.pop('project_name', None)
        attachments = validated_data.pop('attachments', [])

        # ✅ CREATE WITH PROJECT FIELDS
        advance = AdvanceRequest.objects.create(
            project_id=project_id,
            project_name=project_name,
            **validated_data
        )
        
        # Handle attachments - FIXED
        if attachments:
            attachment_paths = []
            for attachment in attachments:
                # ✅ FIXED: Save with proper folder structure
                ext = os.path.splitext(attachment.name)[1]
                filename = f"advance_attachments/advance_{uuid.uuid4()}{ext}"  # Yeh already sahi hai
                
                # Save file
                saved_path = default_storage.save(filename, attachment)
                
                # ✅ FIXED: Store relative path
                attachment_paths.append(filename)  # Store 'uploads/advance_uuid.ext'
            
            advance.attachments = attachment_paths
            advance.save()
        
        return advance

    def update(self, instance, validated_data):
        attachments = validated_data.pop('attachments', None)
        
        instance = super().update(instance, validated_data)
        
        if attachments is not None:
            if instance.attachments is None:
                instance.attachments = []
            
            for attachment in attachments:
                # ✅ FIXED: Consistent naming
                ext = os.path.splitext(attachment.name)[1]
                filename = f"uploads/advance_{uuid.uuid4()}{ext}"
                saved_path = default_storage.save(filename, attachment)
                instance.attachments.append(saved_path)
            
            instance.save()
        
        return instance

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
        employee.set_unusable_password()
        employee.save()
        return employee

    def update(self, instance, validated_data):
        instance = super().update(instance, validated_data)
        return instance 