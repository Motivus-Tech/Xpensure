from django.contrib import admin
from .models import Employee

@admin.register(Employee)
class EmployeeAdmin(admin.ModelAdmin):
    list_display = ('employee_id', 'email', 'full_name', 'department', 'phone_number')
    search_fields = ('employee_id', 'email', 'full_name')
    readonly_fields = ('id',)  # optional
    fieldsets = (
        (None, {
            'fields': ('employee_id', 'email', 'full_name', 'department', 'phone_number', 'aadhar_card', 'password')
        }),
    )
    add_fieldsets = (
        (None, {
            'fields': ('employee_id', 'email', 'full_name', 'department', 'phone_number', 'aadhar_card', 'password')
        }),
    )
