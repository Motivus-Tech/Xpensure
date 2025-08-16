from django.urls import path
from .views import EmployeeSignupView, EmployeeLoginView

urlpatterns = [
    path('employee/signup/', EmployeeSignupView.as_view(), name='employee_signup'),
    path('employee/login/', EmployeeLoginView.as_view(), name='employee_login'),
]