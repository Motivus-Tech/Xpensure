
from rest_framework import serializers
from .models import Employee, Reimbursement, AdvanceRequest
import os
import uuid
from django.core.files.storage import default_storage
from django.conf import settings
from urllib.parse import urljoin

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

def build_absolute_media_url(file_path):
    """
    Helper function to build absolute URL for media files
    Works with AWS IP and any domain
    """
    if not file_path:
        return None
    
    # If already a full URL, return as is
    if isinstance(file_path, str) and (
        file_path.startswith('http://') or 
        file_path.startswith('https://')
    ):
        return file_path
    
    # Remove leading slash if present
    if file_path.startswith('/'):
        file_path = file_path[1:]
    
    # Use BASE_API_URL from settings
    if hasattr(settings, 'BASE_API_URL') and settings.BASE_API_URL:
        base_url = settings.BASE_API_URL.rstrip('/')
        return f"{base_url}/media/{file_path}"
    
    # Fallback
    return f"/media/{file_path}"
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

    def get_attachment_urls(self, obj):
        """Return list of FULL ABSOLUTE attachment URLs"""
        if obj.attachments and isinstance(obj.attachments, list):
            urls = []
            for attachment_path in obj.attachments:
                if attachment_path:
                    try:
                        # ✅ CHECK IF ALREADY A FULL URL
                        if attachment_path.startswith('http://') or attachment_path.startswith('https://'):
                            urls.append(attachment_path)
                            continue
                        
                        # ✅ METHOD 1: Use settings.BASE_API_URL
                        if hasattr(settings, 'BASE_API_URL') and settings.BASE_API_URL:
                            base_url = settings.BASE_API_URL.rstrip('/')
                            media_path = attachment_path.lstrip('/')
                            full_url = f"{base_url}/media/{media_path}"
                        # ✅ METHOD 2: Use request context
                        elif self.context.get('request'):
                            request = self.context['request']
                            full_url = request.build_absolute_uri(f'/media/{attachment_path}')
                        # ✅ METHOD 3: Fallback
                        else:
                            full_url = f'/media/{attachment_path}'
                        
                        urls.append(full_url)
                    except Exception as e:
                        # If error, return the original path
                        print(f"Error generating URL for {attachment_path}: {e}")
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
        
        # Handle attachments - STORE FULL URLs
        if attachments:
            attachment_urls = []
            for attachment in attachments:
                # ✅ Save file with proper folder structure
                ext = os.path.splitext(attachment.name)[1]
                filename = f"reimbursement_attachments/reimbursement_{uuid.uuid4()}{ext}"
                
                # Save file
                saved_path = default_storage.save(filename, attachment)
                
                # ✅ Build FULL URL immediately
                if hasattr(settings, 'BASE_API_URL') and settings.BASE_API_URL:
                    base_url = settings.BASE_API_URL.rstrip('/')
                    file_url = f"{base_url}/media/{saved_path}"
                elif self.context.get('request'):
                    request = self.context['request']
                    file_url = request.build_absolute_uri(f'/media/{saved_path}')
                else:
                    file_url = f"/media/{saved_path}"
                
                attachment_urls.append(file_url)
            
            # ✅ STORE FULL URLs, not paths
            reimbursement.attachments = attachment_urls
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
                # Save file
                ext = os.path.splitext(attachment.name)[1]
                filename = f"uploads/reimbursement_{uuid.uuid4()}{ext}"
                saved_path = default_storage.save(filename, attachment)
                
                # ✅ Build FULL URL
                if hasattr(settings, 'BASE_API_URL') and settings.BASE_API_URL:
                    base_url = settings.BASE_API_URL.rstrip('/')
                    file_url = f"{base_url}/media/{saved_path}"
                elif self.context.get('request'):
                    request = self.context['request']
                    file_url = request.build_absolute_uri(f'/media/{saved_path}')
                else:
                    file_url = f"/media/{saved_path}"
                
                instance.attachments.append(file_url)
            
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
        """Return list of FULL ABSOLUTE attachment URLs"""
        if obj.attachments and isinstance(obj.attachments, list):
            urls = []
            for attachment_path in obj.attachments:
                if attachment_path:
                    try:
                        # ✅ CHECK IF ALREADY A FULL URL
                        if attachment_path.startswith('http://') or attachment_path.startswith('https://'):
                            urls.append(attachment_path)
                            continue
                        
                        # ✅ METHOD 1: Use settings.BASE_API_URL
                        if hasattr(settings, 'BASE_API_URL') and settings.BASE_API_URL:
                            base_url = settings.BASE_API_URL.rstrip('/')
                            media_path = attachment_path.lstrip('/')
                            full_url = f"{base_url}/media/{media_path}"
                        # ✅ METHOD 2: Use request context
                        elif self.context.get('request'):
                            request = self.context['request']
                            full_url = request.build_absolute_uri(f'/media/{attachment_path}')
                        # ✅ METHOD 3: Fallback
                        else:
                            full_url = f'/media/{attachment_path}'
                        
                        urls.append(full_url)
                    except Exception as e:
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
        
        # Handle attachments - STORE FULL URLs
        if attachments:
            attachment_urls = []
            for attachment in attachments:
                # Save file
                ext = os.path.splitext(attachment.name)[1]
                filename = f"advance_attachments/advance_{uuid.uuid4()}{ext}"
                
                # Save file
                saved_path = default_storage.save(filename, attachment)
                
                # ✅ Build FULL URL immediately
                if hasattr(settings, 'BASE_API_URL') and settings.BASE_API_URL:
                    base_url = settings.BASE_API_URL.rstrip('/')
                    file_url = f"{base_url}/media/{saved_path}"
                elif self.context.get('request'):
                    request = self.context['request']
                    file_url = request.build_absolute_uri(f'/media/{saved_path}')
                else:
                    file_url = f"/media/{saved_path}"
                
                attachment_urls.append(file_url)
            
            # ✅ STORE FULL URLs, not paths
            advance.attachments = attachment_urls
            advance.save()
        
        return advance
            
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