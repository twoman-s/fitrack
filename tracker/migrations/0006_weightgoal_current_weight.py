from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('tracker', '0005_alter_weightgoal_options_weightgoal_completed_at_and_more'),
    ]

    operations = [
        migrations.AddField(
            model_name='weightgoal',
            name='current_weight',
            field=models.DecimalField(
                blank=True,
                decimal_places=2,
                max_digits=5,
                null=True,
                verbose_name='current weight at goal start',
            ),
        ),
    ]
