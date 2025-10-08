// Esempio di widget per invitare un utente in una qualsiasi delle sue schermate (es. home_screen.dart)

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:una_social/helpers/snackbar_helper.dart';

class InviteUserWidget extends StatefulWidget {
  const InviteUserWidget({super.key});

  @override
  State<InviteUserWidget> createState() => _InviteUserWidgetState();
}

class _InviteUserWidgetState extends State<InviteUserWidget> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  Future<void> _generateAndShareInvite() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final invitedEmail = _emailController.text.trim();
    final currentUser = Supabase.instance.client.auth.currentUser;
    final inviterName = currentUser?.email ?? 'un amico';

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'create-invite',
        body: {'invited_email': invitedEmail},
      );

      final token = response.data['invite_token'];
      if (token == null) {
        throw Exception('Token di invito non ricevuto dal server.');
      }

      final inviteLink = '/accetta-invito?email=$invitedEmail&token=$token';

      final shareText = 'Ciao! $inviterName ti ha invitato a unirti a Una Social. '
          'Clicca su questo link per completare la registrazione:\n\n'
          'https://<IL_TUO_DOMINIO_APP>$inviteLink';

      final result = await SharePlus.instance.share(
        ShareParams(
          text: shareText,
          subject: 'Invito a Una Social',
        ),
      );

      if (result.status == ShareResultStatus.success) {
        Logger('InviteUser').info('Invito condiviso con successo.');
        if (mounted) {
          SnackbarHelper.showSuccessSnackbar(context, 'Link di invito pronto per la condivisione!');
        }
      }

      _emailController.clear();
    } catch (e) {
      final errorMessage = e is FunctionException ? e.details['error'] ?? e.details['message'] : e.toString();
      Logger('InviteUser').severe('Errore durante la creazione dell\'invito: $errorMessage');
      if (mounted) {
        SnackbarHelper.showErrorSnackbar(context, 'Errore durante la creazione dell\'invito:: $errorMessage');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Invita un nuovo utente', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: 'Email utente da invitare'),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || !value.contains('@')) {
                return 'Inserisci un\'email valida.';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isLoading ? null : _generateAndShareInvite,
            child: _isLoading ? const CircularProgressIndicator() : const Text('Invia Invito'),
          ),
        ],
      ),
    );
  }
}
