# BAZARIO

Azərbaycan dilində onlayn mağaza yaratma platforması.

## Hazırkı vəziyyət

- `main` budağında GitHub Pages üzərindən yayımlanan ilkin demo var. Demo məlumatları yalnız brauzerin `localStorage` yaddaşında saxlanılır.
- `feature/supabase-auth-scaffold` budağında Supabase ilə işləyən draft frontend və backend sxemi hazırlanıb:
  - Satıcı e-poçt/şifrə qeydiyyatı, giriş, sessiyanın bərpası və çıxış.
  - `pending` statusu ilə mağaza yaratmaq və admin təsdiqi.
  - Məhsul əlavə etmək, adı/qiyməti/təsviri redaktə etmək, şəkli təhlükəsiz əvəzləmək, gizlətmək/yayımlamaq və silmək.
  - Təsdiqlənmiş mağazalar üçün `?shop=MAĞAZA-ÜNVANI` ictimai vitrini.
  - Satıcı sifariş siyahısı və qorunan status dəyişmə funksiyası.
  - `admin.html` vasitəsilə pending mağazaları təsdiqləmək və ya rədd etmək.
  - İctimai mağazada məhsul üzrə sifariş formu; server tərəfdə honeypot, rəqəmlərə normallaşdırılmış telefon və eyni mağaza/nömrə üçün saatda maksimum 3 sifariş limiti.
- `supabase/migrations/` qovluğunda cədvəllər, RLS, şəkil Storage-ı, sifariş statusları, admin təsdiqi və qorunan checkout üçün **beş SQL miqrasiyası** var.
- `supabase/verify_installation.sql` miqrasiyalardan sonra quraşdırmanı oxuma rejimində yoxlayır.

## Vacib məhdudiyyətlər

Supabase layihəsi yaradılmayıb, açarlar əlavə edilməyib və miqrasiyalar real bazada icra olunmayıb. Buna görə draft frontend-in real Auth, Storage, mağaza, sifariş və admin funksiyaları canlı sınaqdan keçirilməyib. Checkout qoruması ilkin spam baryeridir; tam CAPTCHA/IP əsaslı limit deyil. İctimai istifadədən əvvəl əlavə anti-bot qoruması və iki ayrı satıcı hesabı ilə təhlükəsizlik sınaqları lazımdır.

`feature/supabase-auth-scaffold` üçün açıq draft [PR №1](https://github.com/8h9z5mcg7v-eng/bazario/pull/1) var. O, `main`-ə birləşdirilməyib. `main`-dəki yayımlanmış demo dəyişdirilməyib.

## Növbəti mərhələlər

1. İstifadəçi ayrıca təsdiqlədikdən sonra Supabase Free layihəsini qurmaq.
2. Beş SQL miqrasiyasını timestamp ardıcıllığı ilə tətbiq etmək.
3. `verify_installation.sql` skriptini işlətmək.
4. `supabase/config.js` faylına yalnız Project URL və public anon/publishable key əlavə etmək.
5. Admin hesabını `admin_users` allow-list-ə daxil edib admin panelini sınamaq.
6. İki ayrı satıcı hesabı, məhsul şəkilləri, ictimai sifariş və status icazələri ilə real təhlükəsizlik sınaqları aparmaq.
7. PR-ı nəzərdən keçirdikdən sonra ayrıca təsdiqlə birləşdirmək və yayımlamaq.

Ödənişli resurs, domen alışı, production deploy və `main` budağına merge ayrıca təsdiq tələb edir. Lovable istifadə edilmir; UstaTap və Taxt və Qılınc repository-lərinə toxunulmur.
