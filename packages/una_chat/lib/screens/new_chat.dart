// packages/una_chat/lib/screens/new_chat.dart

import 'package:flutter/material.dart';
import 'package:una_chat/screens/telephone_number.dart';
import 'package:una_social/helpers/logger_helper.dart';

class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Funzione per mostrare il popup di inserimento numero
  void _showTelephoneNumberPopup() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return const TelephoneNumberPopup();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Questo è il contenuto che verrà mostrato nel BottomSheet
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuova chat'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: Column(
        children: [
          // Barra di ricerca e icona telefono
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Cerca un nome o un numero',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30.0),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainer,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.dialpad, color: theme.iconTheme.color),
                  onPressed: _showTelephoneNumberPopup,
                  tooltip: 'Cerca per numero di telefono',
                ),
              ],
            ),
          ),
          // Opzioni principali (Nuovo gruppo, Nuovo contatto)
          _ActionListItem(
            icon: Icons.group_outlined,
            title: 'Nuovo gruppo',
            onTap: () => logInfo('Tapped "Nuovo gruppo"'),
          ),
          _ActionListItem(
            icon: Icons.person_add_alt_1_outlined,
            title: 'Nuovo contatto',
            onTap: () => logInfo('Tapped "Nuovo contatto"'),
          ),

          // Lista contatti
          Expanded(
            child: ListView(
              children: [
                _SectionHeader(title: 'Contattati di frequente'),
                _ContactListItem(
                  avatarUrl: 'https://placehold.co/64x64/E8AA42/FFFFFF',
                  name: 'Sorina Popa',
                  status: "We'll be always happy and free...",
                ),
                _ContactListItem(
                  avatarUrl: 'https://placehold.co/64x64/35A29F/FFFFFF',
                  name: 'Leonardo Cimarosa',
                  status: 'Non mi fido, in certi casi un pianof...',
                ),
                _SectionHeader(title: 'Tutti i contatti'),
                _ContactListItem(
                  avatarUrl: 'https://placehold.co/64x64/071952/FFFFFF',
                  name: 'Claudia Tassinari',
                  status: 'Disponibile',
                ),
                _ContactListItem(
                  isPhoneNumber: true,
                  name: '+393518984923',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Widget helper per le prime due opzioni (Nuovo gruppo/contatto)
class _ActionListItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ActionListItem({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        child: Icon(icon),
      ),
      title: Text(title),
      onTap: onTap,
    );
  }
}

// Widget helper per gli header delle sezioni
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, top: 16.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// Widget helper per i singoli contatti nella lista
class _ContactListItem extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final String? status;
  final bool isPhoneNumber;

  const _ContactListItem({
    required this.name,
    this.avatarUrl,
    this.status,
    this.isPhoneNumber = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        backgroundImage: (avatarUrl != null) ? NetworkImage(avatarUrl!) : null,
        child: (avatarUrl == null) ? Icon(isPhoneNumber ? Icons.person_pin : Icons.person, color: Colors.grey) : null,
      ),
      title: Text(name),
      subtitle: status != null ? Text(status!, maxLines: 1, overflow: TextOverflow.ellipsis) : null,
      onTap: () => logInfo('Tapped on contact: $name'),
    );
  }
}

/*
  COME USARE QUESTO WIDGET:
  Dalla tua schermata principale della chat (es. una_chat_main_screen.dart),
  chiama questo widget all'interno di un ModalBottomSheet.

  Esempio di chiamata nel pulsante "Nuova Chat":

  IconButton(
    icon: Icon(Icons.edit_outlined),
    onPressed: () {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true, // Permette al sheet di occupare tutto lo schermo
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
        ),
        builder: (context) {
          // Occupa il 95% dell'altezza dello schermo per un look più nativo
          return SizedBox(
            height: MediaQuery.of(context).size.height * 0.95,
            child: const NewChatScreen(),
          );
        },
      );
    },
  ),
*/
