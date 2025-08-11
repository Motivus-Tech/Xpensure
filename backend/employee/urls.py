from django.urls import path
from . import views

urlpatterns = [
    path('register/', views.EmployeeRegistrationView.as_view(), name='employee-register'),
    path('login/', views.EmployeeLoginView.as_view(), name='employee-login'),
]