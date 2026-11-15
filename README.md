# BAZARIO

Azərbaycan dilində onlayn mağaza yaratma platforması.

## Hazırkı vəziyyət

- `main` budağında GitHub Pages üzərindən yayımlanan ilkin demo mövcuddur. Demo məlumatları brauzerin `localStorage` yaddaşında saxlanılır.
- `feature/supabase-auth-scaffold` budağında Supabase ilə inteqrasiya üçün draft frontend hazırlanıb:
  - Satıcı e-poçt/şifrə qeydiyyatı, giriş və sessiyanın bərpası.
  - `pending` statusu ilə mağaza yaratmaq.
  - Məhsul əlavə etmək, şəkilləri Storage-a yükləmək və məhsulları silmək.
  - Təsdiqlənmiş mağazalar üçün `?shop=MAĞAZA-ADRESI` ictimai vitrini.
  - Satıcı sifariş siyahısı və qorunan status dəyişmə funksiyası.
  - `admin.html` vasitəsilə pending mağazaları təsdiqləmək və ya rədd etmək.
  - İctimai mağazada məhsul üzrə sifariş formu; server tərəfdə gizli honeypot və eyni mağaza/telefon üçün saatda maksimum 3 sifariş limiti.
- `supabase/migrations/` qovluğunda cədvəllər, RLS, şəkil Storage-ı, sifariş statusları, admin təsdiqi və qorunan checkout üçün beş SQL miqrasiyası var.
- `supabase/verify_installation.sql` miqrasiyalardan sonra quraşdırmanı oxuma rejimində yoxlayır.

## Vacib məhdudiyyətlər

Supabase layihəsi yaradılmayıb, açarlar əlavə edilməyib və miqrasiyalar real bazada icra olunmayıb. Buna görə draft frontend-in real Auth, Storage, mağaza, sifariş və admin funksiyaları canlı sınaqdan keçirilməyib. Müştəri checkout forması hələ aktiv deyil: ictimai sifariş qəbulundan əvvəl sorğu məhdudlaşdırması/anti-bot qorunması və iki ayrı satıcı hesabı ilə təhlükəsizlik sınaqları lazımdır.

`feature/supabase-auth-scaffold` üçün açıq draft PR №1 var. O, `main`-ə birləşdirilməyib. `main`-dəki yayımlanmış demo dəyişdirilməyib.

## Növbəti mərhələlər

1. İstifadəçi təsdiq etdikdən sonra Supabase Free layihəsini qurmaq.
2. Dörd SQL miqrasiyasını timestamp ardıcıllığı ilə tətbiq edib `verify_installation.sql` skriptini işlətmək.
3. `supabase/config.js` faylına yalnız Project URL və public anon/publishable key əlavə etmək.
4. Admin hesabını `admin_users` allow-list-ə daxil edib `admin.html` panelini sınamaq.
5. Müştəri checkout üçün anti-bot/sorğu məhdudlaşdırması əlavə etmək və real təhlükəsizlik sınaqları aparmaq.
6. PR-ı nəzərdən keçirdikdən sonra ayrıca təsdiqlə birləşdirmək və yayımlamaq.

Ödənişli resurs, domen alışı, production deploy və `main` budağına merge ayrıca təsdiq tələb edir. Lovable istifadə edilmir; UstaTap və Taxt və Qılınc repository-lərinə toxunulmur.
