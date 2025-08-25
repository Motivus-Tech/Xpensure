from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    EmployeeListCreateView,
    EmployeeDetailView,
    EmployeeLoginView,
    EmployeeSignupView,
    ReimbursementViewSet,
    AdvanceRequestViewSet
)

router = DefaultRouter()
router.register(r'reimbursements', ReimbursementViewSet, basename='reimbursement')
router.register(r'advances', AdvanceRequestViewSet, basename='advance')

urlpatterns = [
    path('', include(router.urls)),
    path('employees/', EmployeeListCreateView.as_view(), name='employee-list'),
    path('employees/<str:employee_id>/', EmployeeDetailView.as_view(), name='employee-detail'),
    path('auth/signup/', EmployeeSignupView.as_view(), name='employee-signup'),
    path('auth/login/', EmployeeLoginView.as_view(), name='employee-login'),
]
