from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    EmployeeListCreateView,
    EmployeeDetailView,
    EmployeeLoginView,
    EmployeeSignupView,
    ReimbursementViewSet,
    AdvanceRequestViewSet,
    ReimbursementListCreateView,
    AdvanceRequestListCreateView,
    EmployeeProfileView,
    VerifyPasswordView,
    ChangePasswordView
)

# -----------------------------
# Router for ViewSets
# -----------------------------
router = DefaultRouter()
router.register(r'reimbursements', ReimbursementViewSet, basename='reimbursement')
router.register(r'advances', AdvanceRequestViewSet, basename='advance')

# -----------------------------
# URL Patterns
# -----------------------------
urlpatterns = [
    # ViewSet routes
    path('', include(router.urls)),

    # Employee management
    path('employees/', EmployeeListCreateView.as_view(), name='employee-list'),
    path('employees/<str:employee_id>/', EmployeeDetailView.as_view(), name='employee-detail'),

    # Auth
    path('auth/signup/', EmployeeSignupView.as_view(), name='employee-signup'),
    path('auth/login/', EmployeeLoginView.as_view(), name='employee-login'),

    # Reimbursements / Advances (List + Create)
    path('api/reimbursements/', ReimbursementListCreateView.as_view(), name='reimbursement-list-create'),
    path('api/advances/', AdvanceRequestListCreateView.as_view(), name='advance-list-create'),

    # Employee Profile
    path('employees/<str:employee_id>/profile/', EmployeeProfileView.as_view(), name='employee-profile'),

    # Password endpoints
    path('employees/<str:employee_id>/verify-password/', VerifyPasswordView.as_view(), name='employee-verify-password'),
    path('employees/<str:employee_id>/change-password/', ChangePasswordView.as_view(), name='employee-change-password'),
    path("api/employees/", EmployeeListCreateView.as_view(), name="employee-list-create"),

   
]