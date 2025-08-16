from django.contrib.auth.models import AbstractUser
from django.db import models

class Employee(AbstractUser):
    employee_id = models.CharField(max_length=20, unique=True)
    department = models.CharField(max_length=100, blank=True)
    phone_number = models.CharField(max_length=15, blank=True)
    aadhar_card = models.CharField(max_length=20, blank=True)

    def __str__(self):
        return f"{self.username} ({self.employee_id})"
