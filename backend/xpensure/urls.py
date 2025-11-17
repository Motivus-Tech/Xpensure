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
    ChangePasswordView,
    EmployeeDeleteView,
    ApproveRequestAPIView,
    RejectRequestAPIView,
    PendingApprovalsView,
    FinanceVerificationInsightsView,
    CEODashboardView,
    CEOAnalyticsView,
    CEOHistoryView,
    CEOApproveRequestView,
    CEORejectRequestView,
    CEORequestDetailsView,
    CEOGenerateReportView,
    EmployeeCSVDownloadView,
    ApprovalTimelineView,
    FinanceVerificationDashboardView,
    FinanceVerificationApproveView,
    FinanceVerificationRejectView,
    FinancePaymentDashboardView,
    FinanceMarkAsPaidView,
    FinancePaymentInsightsView,
    EmployeeProjectSpendingView,
    FinanceVerificationHistoryView,
    FinanceVerificationEmployeeProjectReportView,
    FinanceVerificationCSVReportView,
    CEOEmployeeProjectReportView,  # ADD THIS
    CEOCSVReportView,
    health_check
)

router = DefaultRouter()
router.register(r'reimbursements', ReimbursementViewSet, basename='reimbursement')
router.register(r'advances', AdvanceRequestViewSet, basename='advance')

api_patterns = [
    path('', include(router.urls)),

    # Employee management
    path('employees/', EmployeeListCreateView.as_view(), name='employee-list'),
    path('employees/<str:employee_id>/', EmployeeDetailView.as_view(), name='employee-detail'),
    path('employees/<str:employee_id>/delete/', EmployeeDeleteView.as_view(), name='employee-delete'),

    # Authentication
    path('auth/signup/', EmployeeSignupView.as_view(), name='employee-signup'),
    path('auth/login/', EmployeeLoginView.as_view(), name='employee-login'),

    # Reimbursements / Advances (List + Create)
    path('reimbursements/', ReimbursementListCreateView.as_view(), name='reimbursement-list-create'),
    path('advances/', AdvanceRequestListCreateView.as_view(), name='advance-list-create'),

    # Employee Profile
    path('employees/<str:employee_id>/profile/', EmployeeProfileView.as_view(), name='employee-profile'),
    # Add this to your urlpatterns in urls.py
    path('employee/csv-download/', EmployeeCSVDownloadView.as_view(), name='employee-csv-download'),

    # Password endpoints
    path('employees/<str:employee_id>/verify-password/', VerifyPasswordView.as_view(), name='employee-verify-password'),
    path('employees/<str:employee_id>/change-password/', ChangePasswordView.as_view(), name='employee-change-password'),

    # Multi-level Request Approval Workflow
    path('approvals/pending/', PendingApprovalsView.as_view(), name='pending-approvals'),
    path('approvals/<int:request_id>/approve/', ApproveRequestAPIView.as_view(), name='approve-request'),
    path('approvals/<int:request_id>/reject/', RejectRequestAPIView.as_view(), name='reject-request'),

    
    
    path('ceo/dashboard/', CEODashboardView.as_view(), name='ceo-dashboard'),
    path('ceo/analytics/', CEOAnalyticsView.as_view(), name='ceo-analytics'),
    path('ceo/history/', CEOHistoryView.as_view(), name='ceo-history'),
    path('ceo/approve-request/', CEOApproveRequestView.as_view(), name='ceo-approve-request'),
    path('ceo/reject-request/', CEORejectRequestView.as_view(), name='ceo-reject-request'),
    path('ceo/request-details/<int:request_id>/', CEORequestDetailsView.as_view(), name='ceo-request-details'),
    path('ceo/generate-report/', CEOGenerateReportView.as_view(), name='ceo-generate-report'),

    path('approval-timeline/<int:request_id>/', ApprovalTimelineView.as_view(), name='approval-timeline'),

    # Finance Verification URLs
    path('finance-verification/dashboard/', FinanceVerificationDashboardView.as_view(), name='finance-verification-dashboard'),
    path('finance-verification/approve/', FinanceVerificationApproveView.as_view(), name='finance-verification-approve'),
    path('finance-verification/reject/', FinanceVerificationRejectView.as_view(), name='finance-verification-reject'),
    
    # Finance Payment URLs  
    path('finance-payment/dashboard/', FinancePaymentDashboardView.as_view(), name='finance-payment-dashboard'),
    path('finance-payment/mark-paid/', FinanceMarkAsPaidView.as_view(), name='finance-payment-mark-paid'),
    path('finance-payment/insights/',FinancePaymentInsightsView.as_view(), name='finance-payment-insights'),
  
    path('employee-project-spending/', EmployeeProjectSpendingView.as_view(), name='employee-project-spending'),
    # Add this URL pattern in your urlpatterns
    path('finance-verification/insights/', FinanceVerificationInsightsView.as_view(), name='finance-verification-insights'),
    path('finance-verification/history/', FinanceVerificationHistoryView.as_view(), name='finance-verification-history'),
    path('employee-project-report/', FinanceVerificationEmployeeProjectReportView.as_view(), name='finance-verification-employee-project-report'),
    # Health check
    # Add these to your urlpatterns
    path('finance-verification/csv-report/', FinanceVerificationCSVReportView.as_view(), name='finance-verification-csv-report'),
    path('health/', health_check, name='health'),
     # NEW CEO REPORTING ENDPOINTS
    path('ceo/employee-project-report/', CEOEmployeeProjectReportView.as_view(), name='ceo-employee-project-report'),
    path('ceo/csv-report/', CEOCSVReportView.as_view(), name='ceo-csv-report'),

]

urlpatterns = [
    path('', include(api_patterns)),
]