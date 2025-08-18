from django.urls import path
from .views import (
    EmployeeListCreateView,
    EmployeeDetailView,
    EmployeeLoginView,
    EmployeeSignupView
)

urlpatterns = [
    path('employees/', EmployeeListCreateView.as_view(), name='employee-list'),
    path('employees/<str:employee_id>/', EmployeeDetailView.as_view(), name='employee-detail'),
    path('auth/signup/', EmployeeSignupView.as_view(), name='employee-signup'),
    path('auth/login/', EmployeeLoginView.as_view(), name='employee-login'),
]