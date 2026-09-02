from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("otp_auth", "0001_initial"),
    ]

    operations = [
        migrations.AddField(
            model_name="otpchallenge",
            name="contact_verified",
            field=models.BooleanField(default=False),
        ),
    ]
