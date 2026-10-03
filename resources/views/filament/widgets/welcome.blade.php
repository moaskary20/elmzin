<section class="mz-hero">
    <div class="mz-hero-glow"></div>
    <p class="mz-kicker">منصة الحجز</p>
    <h2>مرحباً {{ auth()->user()?->name }}</h2>
    <p class="mz-lead">
        الأقسام الثلاثة تفتح الصالونات، وداخل كل صالون تُدار ساعات العمل والخدمات والأخصائيون وأوقاتهم والتقييم.
    </p>
    <div class="mz-pills">
        <a href="{{ \App\Filament\Resources\CategoryResource::getUrl() }}">رجالي · حريمي · أطفال</a>
        <a href="{{ \App\Filament\Resources\SalonResource::getUrl() }}">الصالونات</a>
        <a href="{{ \App\Filament\Resources\BookingResource::getUrl() }}">الحجوزات</a>
    </div>
</section>
