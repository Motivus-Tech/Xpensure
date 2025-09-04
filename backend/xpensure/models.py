from django.db import models
from django.contrib.auth.models import AbstractBaseUser, PermissionsMixin, BaseUserManager
from django.conf import settings


# -----------------------------
# Employee / Custom User Model
# -----------------------------
class EmployeeManager(BaseUserManager):
    def create_user(self, employee_id, email, fullName, password=None, **extra_fields):
        if not email:
            raise ValueError("Email is required")
        email = self.normalize_email(email)
        user = self.model(
            employee_id=employee_id,
            email=email,
            fullName=fullName,
            **extra_fields
        )
        if password:  # allow HR/employees without password too
            user.set_password(password)
        else:
            user.set_unusable_password()
        user.save(using=self._db)
        return user

    def create_superuser(self, employee_id, email, fullName, password=None, **extra_fields):
        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_superuser", True)
        return self.create_user(employee_id, email, fullName, password, **extra_fields)


class Employee(AbstractBaseUser, PermissionsMixin):
    employee_id = models.CharField(max_length=50, unique=True)
    email = models.EmailField(unique=True)
    fullName = models.CharField(max_length=100, default="Unknown")
    department = models.CharField(max_length=50, blank=True, null=True)
    phone_number = models.CharField(max_length=15, blank=True, null=True)
    aadhar_card = models.CharField(max_length=12, blank=True, null=True)

    # hierarchy
    report_to = models.CharField(max_length=50, null=True, blank=True)


    avatar = models.ImageField(upload_to="avatars/", null=True, blank=True)

    ROLE_CHOICES = [
        ("Common", "Common"),
        ("HR", "HR"),
        ("CEO", "CEO"),
        ("Finance", "Finance"),
    ]
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default="Common")

    is_active = models.BooleanField(default=True)
    is_staff = models.BooleanField(default=False)

    objects = EmployeeManager()

    USERNAME_FIELD = "employee_id"
    REQUIRED_FIELDS = ["email", "fullName"]

    def __str__(self):
        return f"{self.fullName} ({self.employee_id})"


# -----------------------------
# Reimbursement Model
# -----------------------------
class Reimbursement(models.Model):
    STATUS_CHOICES = [
        ("Pending", "Pending"),
        ("Approved", "Approved"),
        ("Rejected", "Rejected"),
    ]

    employee = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        to_field="employee_id",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="reimbursements",
    )
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    description = models.TextField(blank=True, null=True)
    attachment = models.FileField(upload_to="reimbursements/", blank=True, null=True)
    date = models.DateField()
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default="Pending")
    currentStep = models.IntegerField(default=0)
    payments = models.JSONField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.employee_id_display} - {self.amount}"

    @property
    def employee_id_display(self):
        return self.employee.employee_id if self.employee else "Deleted Employee"


# -----------------------------
# Advance Request Model
# -----------------------------
class AdvanceRequest(models.Model):
    STATUS_CHOICES = [
        ("Pending", "Pending"),
        ("Approved", "Approved"),
        ("Rejected", "Rejected"),
    ]

    employee = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        to_field="employee_id",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="advances",
    )
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    description = models.TextField()
    request_date = models.DateField()
    project_date = models.DateField()
    attachment = models.FileField(upload_to="advances/", blank=True, null=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default="Pending")
    currentStep = models.IntegerField(default=0)
    payments = models.JSONField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.employee_id_display} - {self.amount}"

    @property
    def employee_id_display(self):
        return self.employee.employee_id if self.employee else "Deleted Employee"
