# BAZARIO

Azərbaycan dilində onlayn mağaza yaratma platforması.

## Hazırkı mərhələ

Bu repository-də mobil uyğun frontend prototipi və ilkin backend sxemi var:
- BAZARIO ana səhifəsi və nümunə məhsul vitrini
- Demo mağaza yaratma formu və brauzerdə saxlanılan satıcı paneli
- Demo məhsul əlavə etmə, şəkil önizləməsi və sifariş ssenarisi
- GitHub Pages üzərindən yayımlanan demo
- supabase/migrations/20261109000000_initial_schema.sql — satıcı profilləri, mağazalar, məhsullar, sifarişlər, admin rolu, Row Level Security və serverdə qiymət hesablayan sifariş funksiyası üçün ilkin SQL sxemi
- supabase/migrations/20261110000000_product_image_storage.sql — satıcıya məxsus məhsul şəkilləri üçün 1 MB-lıq Storage bucket və sahiblik siyasətləri
- supabase/migrations/20261111000000_seller_order_status_workflow.sql — satıcının sifarişləri mərhələli idarə etməsi üçün təhlükəsiz status dəyişmə funksiyası

## Vacib məhdudiyyət

Frontend hələ localStorage demo rejimindədir. Real qeydiyyat/giriş, server bazası, Storage şəkil yükləməsi, ictimai mağaza URL-ləri, real sifariş API-si və admin paneli sayta qoşulmayıb. İlkin baza, şəkil Storage və sifariş statusu miqrasiyaları repository-dədir, lakin Supabase layihəsinə tətbiq edilməyib. Demo linki real mağaza linki deyil.

## Növbəti mərhələlər

1. Supabase Free limitlərini və layihə qurulmasını təsdiqləmək.
2. SQL sxemini yeni verilənlər bazasına tətbiq etmək və təhlükəsizlik siyasətlərini yoxlamaq.
3. Auth, Storage və real mağaza səhifələrini frontend-ə qoşmaq.
4. Sifarişlərin satıcı panelində görünməsi və admin təsdiqi.
5. Ödənişli paketlər və ödəniş provayderi inteqrasiyası.

Ödənişli xidmətlər, domen alışı və production deploy ayrıca təsdiq tələb edir.
