from pathlib import Path
import os

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Custom user model reference:
AUTH_USER_MODEL = 'Xpensure.Employee'

SECRET_KEY = 'django-insecure-your-secret-key-here'

DEBUG = True

ALLOWED_HOSTS = ['localhost', '127.0.0.1', '192.168.1.5', '192.168.1.7', '10.0.2.2', 
                 '*', '3.110.215.143',  '3.110.215.143:8000' ]

# ✅ ADD THIS FOR ABSOLUTE URLs
BASE_API_URL = 'http://3.110.215.143:8000'  # Development के लिए
# Production में: 'https://api.abc.com'

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',

    'rest_framework',
    'rest_framework.authtoken',

    'Xpensure',
    'corsheaders'
]

MIDDLEWARE = [
    'corsheaders.middleware.CorsMiddleware',  
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'backend.urls'

# ✅ CORS settings update करें
CORS_ALLOW_ALL_ORIGINS = True  # Development के लिए
CORS_ALLOWED_ORIGINS = [
    "http://localhost",
    "http://127.0.0.1",
    "http://10.0.2.2",
    "http://192.168.1.5",
    "http://192.168.1.7",
    "http://3.110.215.143:8000",  # ✅ AWS IP with port
    "http://3.110.215.143",       # ✅ AWS IP without port
    "https://3.110.215.143",      # ✅ HTTPS (if configured)
]
CORS_ALLOW_CREDENTIALS = True

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'backend.wsgi.application'

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'xpensure_db',
        'USER': 'postgres',
        'PASSWORD': 'Xpensure@2025',
        'HOST': '127.0.0.1',
        'PORT': '5432',
    }
}

AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator'},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]

LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'UTC'
USE_I18N = True
USE_TZ = True

STATIC_URL = 'static/'
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': (
        'rest_framework.authentication.TokenAuthentication',
    ),
    'DEFAULT_RENDERER_CLASSES': (
        'rest_framework.renderers.JSONRenderer',
    ),
    'DEFAULT_PERMISSION_CLASSES': (
        'rest_framework.permissions.IsAuthenticated',
    ),
}

# ✅ MEDIA SETTINGS
MEDIA_URL = "/media/"
MEDIA_ROOT = os.path.join(BASE_DIR, "media")

# Ensure media folder exists
MEDIA_DIR = os.path.join(BASE_DIR, 'media')
if not os.path.exists(MEDIA_DIR):
    os.makedirs(MEDIA_DIR)

# Also create uploads folder inside media
UPLOADS_DIR = os.path.join(MEDIA_DIR, 'uploads')
if not os.path.exists(UPLOADS_DIR):
    os.makedirs(UPLOADS_DIR)

print(f"✅ Media URL: {MEDIA_URL}")
print(f"✅ Media Root: {MEDIA_ROOT}")
print(f"✅ Uploads Directory: {UPLOADS_DIR}")
print(f"✅ Base API URL: {BASE_API_URL}")