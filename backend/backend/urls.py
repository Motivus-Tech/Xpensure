from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static


urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/', include('Xpensure.urls')),  # Changed to 'api/' prefix
]


# ✅ IMPORTANT: This must be at the END
if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
    print(f"✅ Media files will be served at: {settings.MEDIA_URL}")   