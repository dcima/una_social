import 'package:flutter/material.dart';

class ImportContactsScreen extends StatefulWidget {
  const ImportContactsScreen({super.key});

  @override
  State<ImportContactsScreen> createState() => _ImportContactsScreenState();
}

class _ImportContactsScreenState extends State<ImportContactsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trova i tuoi Amici'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Per iniziare, connettiti con qualcuno!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Pulsante per importare colleghi (da mostrare condizionalmente)
              ElevatedButton.icon(
                icon: const Icon(Icons.work),
                label: const Text('Importa Colleghi dall\'Università'),
                onPressed: () {
                  // TODO: Implementare la logica per chiamare la funzione `get-colleagues`
                  // e mostrare una lista di persone da invitare/aggiungere.
                },
              ),
              const SizedBox(height: 16),

              // Pulsante per importare dalla rubrica (solo mobile)
              ElevatedButton.icon(
                icon: const Icon(Icons.contacts),
                label: const Text('Invita dalla Rubrica del Telefono'),
                onPressed: () {
                  // TODO: Implementare la logica per accedere ai contatti del dispositivo
                  // e inviare inviti SMS.
                },
              ),
              const SizedBox(height: 16),

              // Pulsante per invitare via email
              ElevatedButton.icon(
                icon: const Icon(Icons.email),
                label: const Text('Invita tramite Email'),
                onPressed: () {
                  // TODO: Mostrare una dialog per inserire l'email
                  // e chiamare la funzione `invite-external-user`.
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
