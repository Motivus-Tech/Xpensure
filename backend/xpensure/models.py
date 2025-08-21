from django.db import models
from django.contrib.auth.models import AbstractBaseUser, PermissionsMixin, BaseUserManager

# Custom User Manager
class EmployeeManager(BaseUserManager):
    def create_user(self, employee_id, email, full_name, password=None, **extra_fields):
        if not email:
            raise ValueError("Email is required")
        email = self.normalize_email(email)
        user = self.model(
            employee_id=employee_id,
            email=email,
            full_name=full_name,
            username=employee_id,  # use employee_id as username
            **extra_fields
        )
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, employee_id, email, full_name, password=None, **extra_fields):
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        return self.create_user(employee_id, email, full_name, password, **extra_fields)


# Custom Employee model
class Employee(AbstractBaseUser, PermissionsMixin):
    employee_id = models.CharField(max_length=50, unique=True)
    email = models.EmailField(unique=True)
    full_name = models.CharField(max_length=100, default="Unknown")  # avoids migration issues
    department = models.CharField(max_length=50, blank=True, null=True)
    phone_number = models.CharField(max_length=15, blank=True, null=True)
    aadhar_card = models.CharField(max_length=12, blank=True, null=True)
    username = models.CharField(max_length=50, unique=True)  # required by AbstractBaseUser

    is_active = models.BooleanField(default=True)
    is_staff = models.BooleanField(default=False)

    objects = EmployeeManager()

    USERNAME_FIELD = 'employee_id'
    REQUIRED_FIELDS = ['email', 'full_name']

    def __str__(self):
        return self.employee_id
