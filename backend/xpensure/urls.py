from django.urls import path
from .views import EmployeeListCreateView, EmployeeDetailView, EmployeeLoginView, EmployeeSignupView

urlpatterns = [
    path('api/employees/', EmployeeListCreateView.as_view(), name='employee-list-create'),
    path('api/employees/<int:pk>/', EmployeeDetailView.as_view(), name='employee-detail'),
    path('api/login/', EmployeeLoginView.as_view(), name='employee-login'),
    path('api/signup/', EmployeeSignupView.as_view(), name='employee-signup'),
]
