from django.urls import path
from .views import EmployeeListCreateView, EmployeeDetailView

urlpatterns = [
    path('api/employees/', EmployeeListCreateView.as_view(), name='employee-list-create'),
    path('api/employees/<int:pk>/', EmployeeDetailView.as_view(), name='employee-detail'),
]
