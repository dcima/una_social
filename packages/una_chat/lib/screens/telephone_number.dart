// packages/una_chat/lib/screens/telephone_number.dart

import 'package:flutter/material.dart';
import 'package:country_picker/country_picker.dart';

class TelephoneNumberPopup extends StatefulWidget {
  const TelephoneNumberPopup({super.key});

  @override
  State<TelephoneNumberPopup> createState() => _TelephoneNumberPopupState();
}

class _TelephoneNumberPopupState extends State<TelephoneNumberPopup> {
  final TextEditingController _phoneController = TextEditingController();

  // AGGIUNTO: Variabile di stato per mantenere il paese selezionato.
  // Inizializziamo con l'Italia come default.
  Country _selectedCountry = Country(
    phoneCode: '39',
    countryCode: 'IT',
    e164Sc: 0,
    geographic: true,
    level: 1,
    name: 'Italia',
    example: 'Italy',
    displayName: 'Italia',
    displayNameNoCountryCode: 'IT',
    e164Key: '',
  );

  void _onKeyPressed(String value) {
    setState(() {
      _phoneController.text += value;
    });
  }

  void _onBackspacePressed() {
    if (_phoneController.text.isNotEmpty) {
      setState(() {
        _phoneController.text = _phoneController.text.substring(0, _phoneController.text.length - 1);
      });
    }
  }

  // AGGIUNTO: Funzione per aprire il selettore di nazioni
  void _openCountryPicker() {
    showCountryPicker(
      context: context,
      showPhoneCode: true, // Mostra il prefisso telefonico accanto al nome del paese
      onSelect: (Country country) {
        // Callback che viene eseguita quando un paese viene selezionato
        setState(() {
          _selectedCountry = country;
        });
      },
      // Personalizzazioni opzionali per un look migliore
      countryListTheme: CountryListThemeData(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20.0),
          topRight: Radius.circular(20.0),
        ),
        // Personalizza lo stile del campo di ricerca
        inputDecoration: InputDecoration(
          labelText: 'Cerca',
          hintText: 'Inizia a digitare per cercare',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderSide: BorderSide(
              // The color is now defined with the alpha value '33' (which is 20% opacity)
              color: const Color(0x338C98A8),
            ),
          ),
        ),
      ),
    );
  }

  // AGGIUNTO: Piccola utility per convertire il codice paese in emoji di bandiera
  String _countryCodeToEmoji(String countryCode) {
    final int firstLetter = countryCode.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final int secondLetter = countryCode.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(firstLetter) + String.fromCharCode(secondLetter);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400.0),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header (invariato)
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  const Text('Numero di telefono', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 20),

              // MODIFICA: Selettore nazione ora è dinamico e cliccabile
              InkWell(
                onTap: _openCountryPicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: theme.colorScheme.primary, width: 2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_countryCodeToEmoji(_selectedCountry.countryCode)}  ${_selectedCountry.name}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // MODIFICA: Campo di testo con prefisso dinamico
              TextField(
                controller: _phoneController,
                readOnly: true,
                style: const TextStyle(fontSize: 18, letterSpacing: 2),
                decoration: InputDecoration(
                  prefixText: '+${_selectedCountry.phoneCode} ', // Prefisso dinamico!
                  prefixStyle: TextStyle(fontSize: 18, color: theme.textTheme.bodyLarge?.color),
                  hintText: '___ _______',
                  suffixIcon: _phoneController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _phoneController.clear()),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Inserisci un numero di telefono per iniziare a chattare.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 20),

              // Tastierino numerico (invariato)
              _DialPad(
                onKeyPressed: _onKeyPressed,
                onBackspacePressed: _onBackspacePressed,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Le classi _DialPad e _DialPadButton rimangono invariate
class _DialPad extends StatelessWidget {
  final Function(String) onKeyPressed;
  final VoidCallback onBackspacePressed;

  const _DialPad({required this.onKeyPressed, required this.onBackspacePressed});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _DialPadButton(number: '1', letters: '', onTap: onKeyPressed),
            _DialPadButton(number: '2', letters: 'ABC', onTap: onKeyPressed),
            _DialPadButton(number: '3', letters: 'DEF', onTap: onKeyPressed),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _DialPadButton(number: '4', letters: 'GHI', onTap: onKeyPressed),
            _DialPadButton(number: '5', letters: 'JKL', onTap: onKeyPressed),
            _DialPadButton(number: '6', letters: 'MNO', onTap: onKeyPressed),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _DialPadButton(number: '7', letters: 'PQRS', onTap: onKeyPressed),
            _DialPadButton(number: '8', letters: 'TUV', onTap: onKeyPressed),
            _DialPadButton(number: '9', letters: 'WXYZ', onTap: onKeyPressed),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _DialPadButton(number: '+', letters: '', onTap: onKeyPressed),
            _DialPadButton(number: '0', letters: '', onTap: onKeyPressed),
            _DialPadButton(
              icon: Icons.backspace_outlined,
              onLongPress: onBackspacePressed,
              onTap: (_) => onBackspacePressed(),
            ),
          ],
        ),
      ],
    );
  }
}

class _DialPadButton extends StatelessWidget {
  final String? number;
  final String? letters;
  final IconData? icon;
  final Function(String)? onTap;
  final VoidCallback? onLongPress;

  const _DialPadButton({this.number, this.letters, this.icon, this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onTap?.call(number ?? ''),
      onLongPress: onLongPress,
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SizedBox(
          width: 50,
          height: 50,
          child: Center(
            child: icon != null
                ? Icon(icon, size: 24)
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(number!, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w400)),
                      if (letters!.isNotEmpty) Text(letters!, style: const TextStyle(fontSize: 10)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
