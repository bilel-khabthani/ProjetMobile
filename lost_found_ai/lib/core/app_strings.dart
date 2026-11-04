abstract final class AppStrings {
  static const String appName = 'Lost&Found AI';
  static const String appTagline = 'Smart Object Recovery';

  static const String onboardingSkip = 'Passer';
  static const String onboardingNext = 'Suivant';
  static const String onboardingStart = 'Commencer';

  static const String welcomeTitle = 'Bonjour !';
  static const String welcomeSubtitle =
      'Récupérez vos affaires plus vite, aidez les autres à retrouver les leurs.';
  static const String createAccount = 'Créer un compte';
  static const String signIn = 'Se connecter';
  static const String orContinueWith = 'ou continuer avec';

  static const String signUpTitle = 'Créer votre compte';
  static const String signUpSubtitle =
      'Deux minutes suffisent pour rejoindre le campus.';
  static const String signInTitle = 'Content de vous revoir';
  static const String signInSubtitle = 'Connectez-vous pour voir vos annonces.';

  static const String fieldName = 'Prénom et nom';
  static const String fieldNameHint = 'Yasmine Benali';
  static const String fieldEmail = 'Adresse e-mail';
  static const String fieldEmailHint = 'amina@campus.fr';
  static const String fieldPhone = 'Téléphone';
  static const String fieldPhoneHint = '+336 12 34 56 78';
  static const String fieldPassword = 'Mot de passe';
  static const String fieldPasswordHint = '8 caractères minimum';
  static const String fieldConfirm = 'Confirmer le mot de passe';
  static const String errorNameRequired = 'Indiquez votre nom';
  static const String errorEmailInvalid = 'Cet e-mail semble incomplet';
  static const String errorPhoneInvalid = 'Numero a 8 chiffres minimum';
  static const String errorPasswordShort = '8 caractères minimum';
  static const String errorPasswordMismatch =
      'Les mots de passe ne correspondent pas';
  static const String errorTerms = 'Acceptez les conditions pour continuer';
  static const String alreadyHaveAccount = 'J’ai déjà un compte';
  static const String noAccountYet = 'Pas encore de compte ?';

  static const String homeGreetingMorning = 'Bonjour';
  static const String homeGreetingAfternoon = 'Bon après-midi';
  static const String homeGreetingEvening = 'Bonsoir';
  static const String actionLostTitle = 'J’ai perdu un objet';
  static const String actionLostSubtitle =
      'Déclarez-le et on cherche pour vous';
  static const String actionFoundTitle = 'J’ai trouvé un objet';
  static const String actionFoundSubtitle =
      'Rendre un objet perdu, ça prend 2 min';
  static const String sectionMatches = 'Correspondances pour vous';
  static const String sectionSeeAll = 'Tout voir';
  static const String sectionActivity = 'Activité récente';
  static String matchesSubtitle(int count) => count == 0
      ? 'Aucune correspondance pour le moment'
      : '$count correspondance${count > 1 ? 's' : ''} détectée${count > 1 ? 's' : ''} par le moteur';

  static String stepOf(int current, int total) => 'Étape $current sur $total';
  static const String stepPhotoTitle = 'Ajouter une photo';
  static const String stepPhotoSubtitle =
      'Une photo nette aide le moteur à reconnaître votre objet.';
  static const String photoDropzone = 'Prendre ou importer une photo';
  static const String photoHint = 'JPG ou PNG · 10 Mo maximum';
  static const String stepDetailsTitle = 'Décrivez votre objet';
  static const String stepDetailsSubtitle = 'Quelques détails suffisent.';
  static const String fieldCategory = 'Catégorie';
  static const String fieldDescription = 'Description';
  static const String fieldDescriptionHint =
      'Ex. : sac noir avec une bande rouge sur le côté';
  static const String errorCategory = 'Choisissez une catégorie';
  static const String errorDescription =
      'Décrivez votre objet en quelques mots';
  static const String stepPlaceTitle = 'Où et quand ?';
  static const String stepPlaceSubtitle =
      'La position et l’heure affinent la correspondance.';
  static const String fieldLocation = 'Lieu';
  static const String fieldDate = 'Date';
  static const String fieldTime = 'Heure';
  static const String useCurrentPosition = 'Utiliser ma position';
  static const String errorLocation =
      'Indiquez où l’objet a été perdu ou trouvé';
  static const String publish = 'Publier l’annonce';
  static const String searching = 'Recherche de correspondances…';
  static const String searchingSubtitle =
      'Notre moteur compare vos annonces à toutes celles du campus.';
  static const String publishedTitle = 'Annonce publiée !';
  static const String publishedSubtitle =
      'Nous vous préviendrons dès qu’une correspondance est trouvée.';
  static const String backHome = 'Retour à l’accueil';

  static const String matchTitle = 'Correspondance trouvée';
  static const String matchScore = 'Score global';
  static const String matchScoreExcellent = 'Correspondance très probable';
  static const String matchScoreGood = 'Correspondance probable';
  static const String matchScoreLow = 'Correspondance incertaine';
  static const String dimensionImage = 'Image';
  static const String dimensionLocation = 'Localisation';
  static const String dimensionTime = 'Horaire';
  static const String dimensionText = 'Description';
  static const String matchHowTitle = 'Comment ce score est calculé ?';
  static const String matchHowBody =
      'Quatre critères sont analysés puis pondérés : ressemblance visuelle, distance géographique, écart horaire et proximité des descriptions.';
  static const String matchFoundBy = 'Trouvé par';
  static String matchFoundAt(String place) => 'Trouvé $place';
  static const String matchYourItem = 'Votre annonce';
  static const String matchOtherItem = 'Annonce trouvée';
  static String distanceMeters(int m) => '$m m de distance';
  static const String answerQuestion = 'Répondre à la question';
  static const String verificationTitle = 'Vérification';
  static const String verificationSubtitle =
      'Pour protéger les vrais propriétaires, répondez à une question secrète.';
  static const String verificationQuestionLabel =
      'Question posée par la personne';
  static const String fieldAnswer = 'Votre réponse';
  static const String fieldAnswerHint = 'Votre réponse';
  static const String verify = 'Vérifier ma réponse';
  static const String answerWrong = 'Réponse incorrecte. Réessayez.';
  static const String answerCorrect = 'Propriétaire vérifié !';
  static const String answerCorrectSubtitle =
      'La mise en relation est débloquée. Vous pouvez maintenant discuter avec la personne qui a trouvé votre objet.';
  static const String continue_ = 'Continuer';
  static const String demoHint =
      'Démo : saisissez « bleue » pour valider la réponse.';

  static const String notifNewMatch = 'Nouvelle correspondance';
  static const String justNow = 'à l’instant';
  static String minutesAgo(int m) => 'il y a $m min';
  static String hoursAgo(int h) => 'il y a ${h}h';
}
