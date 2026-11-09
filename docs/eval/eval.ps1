$base = 'http://localhost:8080'
$token = 'eyJhbGciOiJIUzI1NiJ9.eyJleHAiOjE3OTQ4MDExODQsInN1YiI6IjM4ZmM3MDNiLWQ3MGYtNGU3NC04MjVkLTgxYjRjOThkNzk3NSIsImlhdCI6MTc5NDE5NjM4NH0.15wwa-DbqJ4CXVRdQox5DVj3K-9huIdwgxCvj9uriO8'
$today = (Get-Date).ToString('yyyy-MM-dd')

# 8 danh mục hệ thống
$cats = @(
    @{id = '00000000-0000-4000-8000-000000000001'; category_name = 'Lương'; type = 'INCOME' },
    @{id = '00000000-0000-4000-8000-000000000002'; category_name = 'Thưởng'; type = 'INCOME' },
    @{id = '00000000-0000-4000-8000-000000000003'; category_name = 'Ăn uống'; type = 'EXPENSE' },
    @{id = '00000000-0000-4000-8000-000000000004'; category_name = 'Di chuyển'; type = 'EXPENSE' },
    @{id = '00000000-0000-4000-8000-000000000005'; category_name = 'Mua sắm'; type = 'EXPENSE' },
    @{id = '00000000-0000-4000-8000-000000000006'; category_name = 'Hóa đơn'; type = 'EXPENSE' },
    @{id = '00000000-0000-4000-8000-000000000007'; category_name = 'Giải trí'; type = 'EXPENSE' },
    @{id = '00000000-0000-4000-8000-000000000008'; category_name = 'Sức khỏe'; type = 'EXPENSE' }
)

# cat = 2 số cuối UUID danh mục chuẩn; để trống = kỳ vọng null. date TODAY = hôm nay
$rows = @'
ref|src|status|amount|type|date|cat|text
M01|SMS|PARSED|50000|EXPENSE|2026-11-05|03|VCB 05/11/2026 14:05 TK ****1234 GD: -50,000 VND. ND: HIGHLANDS COFFEE. SD: 2,350,000 VND
M02|SMS|PARSED|185000|EXPENSE|2026-11-06|04|TPBank: TK 8888 -185.000d luc 06/11 19:30 tai GRAB*VN CHUYEN DI. So du 1.200.000d
M03|SMS|PARSED|1299000|EXPENSE|2026-11-03|05|MB: TK ****5678 -1,299,000 VND 03/11 10:12 TT TIKI.VN DON 8821. SD 4,100,000
M04|SMS|PARSED|420000|EXPENSE|2026-11-02|06|BIDV: TK 1234****9 giam 420,000 VND vao 02/11/2026 08:40 THANH TOAN HOA DON DIEN EVN HCM. So du: 3,000,000
M05|SMS|PARSED|90000|EXPENSE|2026-11-07|07|ACB: -90,000 VND 07/11 21:15 NETFLIX.COM. SD 800,000
M06|SMS|PARSED|250000|EXPENSE|2026-11-04|08|Techcombank: TK ****4321 -250,000 VND 04/11 17:20 NHA THUOC LONG CHAU. So du 1,500,000
M07|SMS|PARSED|320000|EXPENSE|2026-11-01|05|VCB: TK ****1234 -320,000 VND 01/11/2026 12:30 ND: SHOPEEPAY THANH TOAN
M08|SMS|PARSED|15000000|INCOME|2026-11-05|01|VCB 05/11/2026 09:00 TK ****1234 +15,000,000 VND. ND: CONG TY ABC LUONG THANG 10. SD 17,350,000
M09|SMS|PARSED|2000000|INCOME|2026-11-06|02|MB: TK ****5678 +2,000,000 VND 06/11 10:00 ND: THUONG DU AN Q3. SD 6,100,000
M10|SMS|PARSED|500000|INCOME|2026-11-07||TPBank: TK 8888 +500.000d luc 07/11 15:45. ND: NGUYEN VAN A CK TIEN AN
M11|TEXT|PARSED|45000|EXPENSE|TODAY|03|an pho 45k sang nay
M12|TEXT|PARSED|150000|EXPENSE|2026-11-07|04|hôm qua đổ xăng 150k
M13|TEXT|PARSED|12500000|INCOME|TODAY|01|Nhận lương tháng 11: 12tr5
M14|TEXT|PARSED|1200000|EXPENSE|2026-11-03|05|mua áo 1tr2 ở shopee ngày 3/11
M15|TEXT|PARSED|280000|EXPENSE|TODAY|06|Trả tiền net FPT 280.000đ
M16|TEXT|PARSED|190000|EXPENSE|2026-11-06|07|Xem phim CGV 2 vé 190k 06/11
M17|TEXT|PARSED|350000|EXPENSE|2026-11-02|08|khám bệnh 350 nghìn ngày 2/11
M18|SMS|PARSED|75000|EXPENSE|2026-11-07|03|Vietinbank 07/11 TK ****9090 -75,000VND ND: PHUC LONG COFFEE
M19|SMS|PARSED|230000|EXPENSE|2026-11-04|04|Your acct ****1234 was debited VND 230,000 on 04-NOV-2026 at GRAB VN. Avail bal VND 900,000
M20|SMS|PARSED|60000|EXPENSE|TODAY|03|MB: TK ****5678 -60,000 VND 20/11/2026 ND: QUAN COM TAM
M21|SMS|NOT_A_TRANSACTION||||| Ngan hang ABC: Ma OTP cua ban la 482913. Khong chia se ma nay voi bat ky ai.
M22|SMS|NOT_A_TRANSACTION|||||[QC] Vay tieu dung lai suat 0%, nhan ngay 50 trieu chi voi CMND. Goi 1900xxxx
M23|SMS|NOT_A_TRANSACTION|||||VCB: So du TK ****1234 hien tai la 2,350,000 VND luc 08/11/2026 10:00
M24|SMS|NOT_A_TRANSACTION|||||Chao ban, hom nay Shopee giam 50% toan bo san pham. Mua ngay!
M25|SMS|NOT_A_TRANSACTION|||||Ban co 1 cuoc goi nho tu so 0901xxx luc 09:12 hom nay.
M26|TEXT|NOT_A_TRANSACTION|||||Mai 8h họp nhóm nhé mọi người
M27|SMS|NOT_A_TRANSACTION|||||MB: the tin dung ****7777 den han thanh toan toi thieu 500,000 VND truoc 15/11
M28|SMS|PARSED|120000|INCOME|2026-11-06||VCB: TK ****1234 +120,000 VND 06/11 ND: HOAN TIEN DON HANG SHOPEE
M29|SMS|PARSED|2500000|EXPENSE|2026-11-05||BIDV: TK ****2468 -2,500,000 VND 05/11 ND: DONG HOC PHI HK1. Phi 1,100 VND. SD 7,000,000
M30|TEXT|PARSED|95000|EXPENSE|TODAY|03|Cafe 35k, ăn trưa 60k
'@ | ConvertFrom-Csv -Delimiter '|'

$res = @{}
for ($i = 0; $i -lt $rows.Count; $i += 10) {
    $b = $rows[$i..([Math]::Min($i + 9, $rows.Count - 1))]
    $body = @{ items = @($b | % { @{ ref = $_.ref; source = $_.src; content = $_.text.Trim() } }); categories = $cats } | ConvertTo-Json -Depth 5
    $r = Invoke-RestMethod -Method Post -Uri "$base/ai/parse-text" -Headers @{ Authorization = "Bearer $token" } `
        -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body))
    foreach ($x in $r.results) { $res[$x.ref] = $x }
    Start-Sleep -Seconds 2
}

$out = foreach ($c in $rows) {
    $x = $res[$c.ref]; $s = $x.suggestion; $p = $c.status -eq 'PARSED'
    $expDate = if ($c.date -eq 'TODAY') { $today } else { $c.date }
    $expCat = if ($c.cat) { "00000000-0000-4000-8000-0000000000$($c.cat)" } else { $null }
    $gotDate = if ($s) { ([datetime]$s.transaction_date).ToString('yyyy-MM-dd') } else { $null }
    $o = [pscustomobject]@{
        ref = $c.ref; exp = $c.status; got = $x.status; conf = $s.confidence
        statusOk = ($x.status -eq $c.status)
        amountOk = if ($p -and $s) { [long]$s.amount -eq [long]$c.amount } else { $null }
        typeOk = if ($p -and $s) { $s.type -eq $c.type } else { $null }
        dateOk = if ($p -and $s) { $gotDate -eq $expDate } else { $null }
        catOk = if ($p -and $s) { $s.category_id -eq $expCat } else { $null }
    }
    $o | Add-Member allOk ($o.statusOk -and (-not $p -or ($o.amountOk -and $o.typeOk -and $o.dateOk -and $o.catOk)))
    $o
}

$P = $out | ? { $_.exp -eq 'PARSED' }
$N = $out | ? { $_.exp -eq 'NOT_A_TRANSACTION' }
function pct($a, $n) { '{0}/{1} = {2:P0}' -f $a, $n, ($a / [Math]::Max($n, 1)) }
"Phân loại đúng (30 tin):     " + (pct ($out | ? statusOk).Count $out.Count)
"Tin giao dịch parse được:    " + (pct ($P | ? statusOk).Count $P.Count)
"Tin rác bị bỏ đúng:          " + (pct ($N | ? statusOk).Count $N.Count)
"Số tiền đúng:                " + (pct ($P | ? amountOk).Count $P.Count)
"Loại thu/chi đúng:           " + (pct ($P | ? typeOk).Count $P.Count)
"Ngày đúng:                   " + (pct ($P | ? dateOk).Count $P.Count)
"Danh mục đúng:               " + (pct ($P | ? catOk).Count $P.Count)
"Đúng toàn bộ trường:         " + (pct ($P | ? allOk).Count $P.Count)
"Dương tính giả (rác bị parse): " + (($N | ? { $_.got -eq 'PARSED' }).Count)
"`nCác ca sai:"; $out | ? { -not $_.allOk } | ft -AutoSize
$out | Export-Csv "eval_$(Get-Date -f HHmm).csv" -NoTypeInformation -Encoding UTF8