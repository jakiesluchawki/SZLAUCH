# Szlauch

Lekka aplikacja menu bar dla macOS. Pokazuje bieżące tempo wysyłania i pobierania na zewnętrznych łączach Maca, a po kliknięciu otwiera panel z metrykami pracy oraz szybkimi przełącznikami.

## Instalacja z DMG

1. Pobierz najnowszy plik `Szlauch-*.dmg` z sekcji GitHub Releases.
2. Otwórz obraz i przeciągnij `Szlauch.app` do `Applications`.
3. Przy pierwszym uruchomieniu wersji bez podpisu Apple macOS może ją zablokować. Wtedy otwórz `Ustawienia systemowe` > `Prywatność i ochrona` i przy komunikacie o `Szlauch` wybierz `Otwórz mimo to`.

Pobieraj aplikację tylko z wydania opublikowanego w tym repozytorium. Publiczne wydania bez certyfikatu Apple Developer są bezpłatne, ale wymagają powyższego jednorazowego potwierdzenia.

Aktualizacja z wcześniejszego prototypu `Pulse Bar` jednorazowo przenosi lokalne ustawienia, wybrany profil VPN i historię transferu do aplikacji `Szlauch`.

## Funkcje

- Dwie linie transferu w menu barze jak w iStat: upload u góry, download pod spodem, z ostatniej pełnej 1-sekundowej próbki; jednostka nie przeskakuje przy zmianie ruchu.
- Natywny wygląd macOS 26 z Liquid Glass, dynamicznym kolorem akcentu i systemową typografią.
- Stały rozmiar panelu: szczegóły przenikają w miejscu, bez resize'u okna ani przeskoku strzałki przy kliknięciu.
- Dyskretna zębatka obok częstotliwości odczytu grupuje ustawienia użytkowe, w tym start przy logowaniu i zakończenie aplikacji, bez zajmowania miejsca pod danymi.
- Przy pierwszym uruchomieniu panel otwiera się raz automatycznie, aby potwierdzić, że aplikacja menu bar działa mimo braku ikony w Docku.
- Kliknięcie napisu `Szlauch` przełącza trzy dopracowane palety: nocną `Śliwkę` (domyślną), zielony `Mech` i morską `Zatokę`. Pobieranie pozostaje chłodne, a wysyłanie ciepłe w każdej palecie; przeciągnięcie w lewo lub prawo reguluje intensywność koloru, a w górę lub dół przezroczystość całego okna.
- Odczyt sumy aktywnych fizycznych łączy Maca i lokalnego IPv4 bez zewnętrznych usług; panel oznacza ten odczyt jako `TRANSFER · CAŁY MAC` i pokazuje mierzony interfejs, więc Wi-Fi nie jest mylone ze źródłem wszystkich danych. VPN działający na routerze jest widoczny normalnie jako ruch Wi-Fi/Ethernet.
- Panel pokazuje jawne źródło interfejsu, aktualny odczyt 1-sekundowy i spokojniejszą średnią z 5 sekund.
- Subtelne wykresy ostatnich 30 sekund są rysowane w tle kafelków uploadu i downloadu.
- Kliknięcie kafelków transferu rozwija liniowy wykres z opisaną skalą i osią czasu: zakresy `15 MIN` i `1 H` zapisują rzeczywiste próbki co 5 sekund, a `DZIŚ` pokazuje czytelny trend co 15 minut, maksimum, średnią oraz lokalny bilans Wi-Fi i hotspotu. Kolejność pozostaje stała: `DOWNLOAD` po lewej, `UPLOAD` po prawej. Mikro-menu jednostki ustawia jedną stałą wartość dla panelu i paska: domyślnie `MB/s` (megabajty), a alternatywnie `Mb/s` (megabity, jak w ofertach łącza) lub `KB/s`.
- Panel pokazuje rzeczywisty stan Wi-Fi, sygnalizuje słaby zasięg i pozwala wybrać sieć z przewijanej listy pobliskich SSID; aktywna sieć jest oznaczona i nie uruchamia ponownego łączenia ani formularza hasła. Przy zmianie sieci Szlauch najpierw korzysta z danych zapamiętanych przez macOS, a o hasło pyta dopiero wtedy, gdy system naprawdę go potrzebuje. Kliknięcie ikony Wi-Fi otwiera bezpośrednio zakładkę Wi-Fi w Ustawieniach systemowych.
- W `SIECI` można raz ustawić osobisty hotspot telefonu i później przełączać się na niego jednym kliknięciem, bez ręcznego szukania go w Ustawieniach. Szlauch próbuje najpierw sieci zapamiętanej w macOS, a następnie wyszukuje wskazany SSID także jako ukryty.
- Przy pierwszym wejściu w `SIECI` aplikacja sama wywołuje systemową zgodę wymaganą przez macOS do odczytu nazw sieci, a gdy zgoda wymaga ręcznej zmiany, prowadzi bezpośrednio do `Usług lokalizacji`.
- Kompaktowe użycie CPU i pamięci RAM; kliknięcie rozwija smukły wykres rdzeni z maksimum oraz osiem aplikacji zużywających najwięcej CPU/RAM.
- Widoki analityczne zachowują kontekst: szczegóły CPU/RAM pokazują na górze bieżący transfer z wejściem do wykresu, a szczegóły transferu pokazują skrót CPU/RAM z wejściem do listy procesów.
- Z widoku sieci, wykresu, procesów i historii hotspotu można wrócić klikając pasywne tło panelu albo jawne `WRÓĆ`; przyciski nadal wykonują swoje akcje. Pogoda pozostaje wyjątkiem: `WIĘCEJ` rozwija prognozę, a temperatura i ikona pogody otwierają aplikację Pogoda.
- Pogoda w panelu: domyślnie dla lokalizacji Maca, z możliwością wyszukania innej miejscowości; pasek pozostaje oszczędny i pokazuje transfer.
- Zwarte rozwinięcie `WIĘCEJ` z czterema kafelkami w skali `4 H`, `12 H` lub `24 H` (co 1, 3 lub 6 godzin), zmianą miejscowości i przejściem do aplikacji Pogoda.
- Rozwinięcie pogody wykorzystuje wolne miejsce na jeden spokojny blok `WARUNKI`: temperaturę odczuwalną pokazuje tylko wtedy, gdy realnie różni się od bieżącej, a wiatr, porywy, opad i jakość powietrza dostają kolor wyłącznie przy wartości wartej uwagi.
- Trzy darmowe źródła prognozy bez kluczy są zebrane w jednym mikro-menu `ŹRÓDŁO`: automatyczny wybór Open-Meteo, europejski model DWD ICON oraz niezależny MET Norway.
- Wiersz `HOTSPOT · DZIŚ` pokazuje pobieranie i wysyłanie na połączeniach oznaczonych przez macOS jako kosztowne. `7 DNI` rozwija spokojny przegląd ostatnich siedmiu dni z porównaniem dziennego pobierania; zapis jest utrzymywany lokalnie przez 31 dni i można go wyczyścić jednym poleceniem.
- Włączanie i wyłączanie własnego, zapamiętanego tunelu WireGuard jest jawnie opisane jako `VPN lokalny`: aktywne połączenie ma pierwszeństwo, przy jednym dostępnym tunelu wybór odbywa się automatycznie, a nazwa konkretnej osoby nie jest zaszyta w aplikacji.
- Przełączenie systemowej blokady sleep: przed jednorazowym systemowym oknem hasła panel wyjaśnia, że hasło odbiera wyłącznie macOS, a nadawana zgoda pozwala tylko włączać i wyłączać blokadę uśpienia. Menu przy przełączniku pozwala później usunąć tę zgodę.
- Opcjonalne uruchamianie przy logowaniu.
- Oszczędna praca w tle: przy zamkniętym panelu sekundowy pozostaje wyłącznie licznik transferu, a cięższe odczyty Wi-Fi, systemu i VPN są ograniczone do potrzeb widoku. Szlauch pilnuje jednej działającej instancji; okna developerskiego podglądu nigdy nie dopisują danych do historii.

## Build

```bash
./scripts/build-macos-app.sh
open -na "Szlauch.app"
```

Build tworzy aplikację universal dla Apple Silicon i Intel z minimalną wersją systemu macOS 13.

Test wyboru profilu WireGuard bez przełączania bieżącego tunelu:

```bash
"Szlauch.app/Contents/MacOS/Szlauch" --self-test-vpn
"Szlauch.app/Contents/MacOS/Szlauch" --self-test-sleep
"Szlauch.app/Contents/MacOS/Szlauch" --self-test-rate-format
"Szlauch.app/Contents/MacOS/Szlauch" --self-test-network
"Szlauch.app/Contents/MacOS/Szlauch" --self-test-hotspot-history
"Szlauch.app/Contents/MacOS/Szlauch" --self-test-personal-hotspot
"Szlauch.app/Contents/MacOS/Szlauch" --self-test-wifi-selection
"Szlauch.app/Contents/MacOS/Szlauch" --self-test-navigation
"Szlauch.app/Contents/MacOS/Szlauch" --self-test-weather
"Szlauch.app/Contents/MacOS/Szlauch" --self-test-runtime
"Szlauch.app/Contents/MacOS/Szlauch" --self-test-theme
```

## DMG

```bash
./scripts/build-dmg.sh
./scripts/test-release.sh
```

Skrypt generuje w `dist/` neutralny instalator drag-and-drop z aliasem `Applications`. Podpisana paczka przeznaczona do wysyłki wymaga certyfikatu Apple Developer oraz zapisanego profilu notaryzacji:

```bash
SZLAUCH_SIGN_IDENTITY="Developer ID Application: ..." \
SZLAUCH_NOTARY_PROFILE="SzlauchNotary" \
./scripts/build-dmg.sh
```

Bez `Developer ID Application` skrypt nadal tworzy sprawny DMG do lokalnych testów, ale macOS może zablokować aplikację pobraną przez inną osobę.

## Prywatność i uprawnienia

Szlauch zapisuje historię transferu i ustawienia wyłącznie lokalnie. Do pobierania
prognozy wysyła lokalizację lub wybraną miejscowość do dostawcy pogody. Lokalizacja
jest również wymagana przez macOS do wyświetlania nazw pobliskich sieci Wi-Fi.
Szczegóły opisuje [PRIVACY.md](PRIVACY.md).

Historia hotspotu nalicza dane wyłącznie wtedy, gdy `Szlauch.app` działa. Nie obejmuje ruchu telefonu ani innych urządzeń podpiętych do hotspotu. `Hotspot` oznacza połączenie zgłaszane przez macOS jako kosztowne, na przykład tethering telefonu; dzienne sumy można wyzerować z rozwinięcia `7 DNI`. Dla ciągłego pomiaru warto włączyć opcję uruchamiania przy logowaniu.

Szybkie łączenie z telefonem zapisuje lokalnie tylko wskazaną nazwę sieci. Publiczne API macOS pozwala Szlauchowi przełączać się na dostępny albo już zapamiętany hotspot, ale nie udostępnia aplikacjom listy urządzeń `Instant Hotspot` pokazywanej przez systemowy panel Continuity. Jeżeli telefon nie nadaje sieci w danej chwili, trzeba najpierw włączyć `Hotspot osobisty` na telefonie.

Bilans ruchu w szczegółach transferu sumuje aktywne fizyczne łącza Maca, na przykład równoczesne Wi-Fi i USB LAN, ale nie dodaje osobno wirtualnego interfejsu VPN, aby nie liczyć tych samych danych dwukrotnie. VPN skonfigurowany na routerze przechodzi przez zwykłe Wi-Fi lub Ethernet, więc jest objęty pomiarem. Rozbicie pokazuje wartości `Wi-Fi`, `Hotspot` i innych łączy, a znacznik `TERAZ` wskazuje kategorię aktualnie naliczaną.

Prognoza domyślnie pochodzi z automatycznego modelu Open-Meteo. W rozwinięciu można przełączyć dane na DWD ICON lub MET Norway bez rejestracji i klucza API. Jakość powietrza jest pobierana osobno z Open-Meteo Air Quality API i pokazuje europejski AQI oraz PM2.5. Systemowa aplikacja Pogoda jest szybkim dodatkowym widokiem lokalizacji, a nie źródłem odczytywanym bezpośrednio przez aplikację.

Sterowanie VPN wymaga zainstalowanego WireGuard i co najmniej jednego tunelu. Szlauch steruje usługą VPN WireGuard zarejestrowaną w macOS, a nie samym oknem aplikacji WireGuard. Na każdym Macu zapamiętuje osobno ostatnio aktywny tunel. Jeśli na komputerze jest kilka tuneli i żaden nie był wcześniej wybrany przez Szlauch, wystarczy raz połączyć właściwy tunel w WireGuard; aplikacja go zapamięta i od tej chwili pozwoli nim sterować z paska, także po zamknięciu aplikacji WireGuard.

Przy pierwszym użyciu `Nie usypiaj` Szlauch prosi macOS o jednorazową zgodę administratora. Tworzy ona ograniczoną regułę tylko dla dwóch poleceń przełączających systemową blokadę uśpienia; aplikacja nie otrzymuje i nie zapisuje hasła. Anulowanie systemowego okna nie jest błędem i nie pozostawia komunikatu w panelu. Zgodę można wycofać z menu `...` przy przełączniku `Nie usypiaj`; macOS poprosi wtedy o autoryzację do usunięcia reguły.
