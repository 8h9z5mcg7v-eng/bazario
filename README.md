# BAZARIO

Azərbaycan dilində onlayn mağaza yaratma platforması.

## Hazırkı mərhələ

Bu repository-də mobil uyğun frontend prototipi və ilkin backend sxemi var:
- BAZARIO ana səhifəsi və nümunə məhsul vitrini
- Demo mağaza yaratma formu və brauzerdə saxlanılan satıcı paneli
- Demo məhsul əlavə etmə, şəkil önizləməsi və sifariş ssenarisi
- GitHub Pages üzərindən yayımlanan demo
- `supabase/migrations/20261109000000_initial_schema.sql` — satıcı profilləri, mağazalar, məhsullar, sifarişlər, admin rolu, Row Level Security və serverdə qiymət hesablayan sifariş funksiyası üçün ilkin SQL sxemi
- `supabase/migrations/20261110000000_product_image_storage.sql` — satıcıya məxsus məhsul şəkilləri üçün 1 MB-lıq Storage bucket və sahiblik siyasətləri
- `supabase/migrations/20261111000000_seller_order_status_workflow.sql` — satıcının sifarişləri mərhələli idarə etməsi üçün təhlükəsiz status dəyişmə funksiyası
- `supabase/verify_installation.sql` — miqrasiyalardan sonra cədvəlləri, RLS, Storage və icazələri yoxlayan read-only SQL skripti
- `supabase/config.js` — Supabase URL və public anon/publishable key üçün boş, təhlükəsiz konfiqurasiya nümunəsi
- Saytda opsional Supabase email/şifrə qeydiyyatı, giriş, sessiyanın bərpası və ilk mağazanın `pending` statusu ilə yaradılması

## Vacib məhdudiyyət

Frontend demo rejimini saxlayır və Supabase Auth yalnız `supabase/config.js` real Project URL və public anon/publishable key ilə doldurulduqdan, miqrasiyalar Supabase-ə tətbiq edildikdən sonra işləyə bilər. Auth qeydiyyatı/girişi və ilk mağazanın `pending` statusu ilə yaradılması üçün kod əlavə olunub, lakin canlı Supabase layihəsi olmadığına görə real bağlantı sınaqdan keçirilməyib. Məhsul CRUD, Storage yükləməsi, ictimai mağaza URL-ləri, real sifariş API-si və admin paneli hələ qoşulmayıb.

## Növbəti mərhələlər

1. Supabase Free limitlərini və layihə qurulmasını təsdiqləmək.
2. SQL sxemini yeni verilənlər bazasına tətbiq etmək və `verify_installation.sql` ilə ilkin yoxlama aparmaq.
3. Auth, Storage və real mağaza səhifələrini frontend-ə qoşmaq.
4. Sifarişlərin satıcı panelində görünməsi və admin təsdiqi.
5. Ödənişli paketlər və ödəniş provayderi inteqrasiyası.

Ödənişli xidmətlər, domen alışı və production deploy ayrıca təsdiq tələb edir.
