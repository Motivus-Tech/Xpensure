from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from .models import Employee

class EmployeeAdmin(UserAdmin):
    model = Employee
    fieldsets = UserAdmin.fieldsets + (
        (None, {'fields': ('employee_id', 'department', 'phone_number', 'aadhar_card')}),
    )
    add_fieldsets = UserAdmin.add_fieldsets + (
        (None, {'fields': ('employee_id', 'department', 'phone_number', 'aadhar_card')}),
    )

admin.site.register(Employee, EmployeeAdmin)
