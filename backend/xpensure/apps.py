from django.apps import AppConfig
from django.db.models.signals import post_migrate

class XpensureConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'Xpensure'

    def ready(self):
        from .models import Employee

        def set_unusable_password(sender, **kwargs):
            for emp in Employee.objects.all():
                # agar password set hai aur employee abhi signup nahi kiya
                if emp.has_usable_password():
                    emp.set_unusable_password()
                    emp.save()

        post_migrate.connect(set_unusable_password, sender=self)
