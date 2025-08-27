from django.urls import path, include
from rest_framework.routers import DefaultRouter
from . import views

from .views import (
    EmployeeListCreateView,
    EmployeeDetailView,
    EmployeeLoginView,
    EmployeeSignupView,
    ReimbursementViewSet,
    AdvanceRequestViewSet,
    ReimbursementListCreateView,
    AdvanceRequestListCreateView
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
    path('api/reimbursements/', ReimbursementListCreateView.as_view(), name='reimbursement-list-create'),
    path('api/advances/', AdvanceRequestListCreateView.as_view(), name='advance-list-create'),
    path('employees/<str:employee_id>/', views.EmployeeProfileView.as_view(), name='employee-profile'),
    path('employees/<str:employee_id>/verify-password/', views.VerifyPasswordView.as_view(), name='employee-verify-password'),
    path('employees/<str:employee_id>/change-password/', views.ChangePasswordView.as_view(), name='employee-change-password'),
    
]
