/**
  FaceBook Registration Handler example
**/
global class SocialCustomRegistrationHandler implements Auth.RegistrationHandler{

	private void myNewMethod(){

	}

	private static final String ORG_SUFFIX = '.sso.badge.org';
	private static final String DEFAULT_ACCOUNTNAME = 'Canarie';
	private static final String EXTERNAL_USER_PROFILE = 'CUST-Customer Portal Manager Standard';
	private static final String INTERNAL_USER_PROFILE = 'Standard User';

	/**
	 * Let anyone register as long as the required fields are supplied
	 *
	 * We require email, lastName, firstName
	 *
	 * @data - the user's info from the Auth Provider
	 **/
	global boolean canCreateUser(Auth.UserData data) {
		System.debug('canCreateUser was called for ' + (data != null ? data.email : 'null'));
		Boolean retVal = (data != null
			&& data.email != null
			&& data.lastName != null
			&& data.firstName != null);

		System.debug('data.username='+data.username);
		System.debug('data.email='+data.email);
		System.debug('data.lastName='+data.lastName);
		System.debug('data.firstName='+data.firstName);

		system.debug('Auth.UserData='+data);
		return retVal;
	}

	/*  Nel momento in cui faccio la Login da FaceBook, mi metto nell'ipotesi che l'utenza sia già stata registrata.
		In questo scenario non devo creare una nuova utenza, ma solo aggiornarla in modo da creare il link tra user - remote Access Provider.
		Una volta creato il link tutte le volte che faccio login il mio utente risulta aggianciato a FaceBook.
	*/
	global User createUser(Id portalId, Auth.UserData data){

		system.debug('Map:' + data.attributeMap);

		//Se esiste già uno user con stesso identifier aggiorno lo user in modo da agganciare il Service Provider Facebook
		List<User> lU = [select id from User where Facebook_remote_identifier__c=: data.identifier];
		if(lU.size() > 0){
			updateUser(lU[0].Id, null, data);
			return lU[0];
		}
		else{
			return null;
		}

	}

	/**
	 * Update the user
	 * @param portalId  - Id of the Community
	 * @param data - Auth Provider user data describing the User to create
	 **/
	global void updateUser(Id userId, Id portalId, Auth.UserData data){
		System.debug('Update User called for: ' + data.email);
		system.debug('userId: ' + userId + ' - portalId: ' + portalId + ' - Auth.UserData: ' + data);

		User u = new User(id=userId);
		u.Origin__c = 'Facebook';
		update u;
		/*User u = new User(id=userId);
		u.email = data.email;
		u.lastName = data.lastName;
		u.firstName = data.firstName;
		update(u);*/
	}
	/**
	 * Create a Contact
	 *
	 * @param data - Facebook provided context for the User
	 **/
	private Id createContact(Auth.UserData data){
		Contact contact = new Contact();
		contact.LastName = data.lastName;
		contact.FirstName = data.firstName;
		contact.Email = data.email;

		// set Account Id
		if (data.attributemap.get('accountId') != null){
			contact.accountId = data.attributemap.get('accountId');
		} else {
			List<Account> accounts = [select Id from Account where Name =:DEFAULT_ACCOUNTNAME];
			System.debug('Found account: ' + accounts);

			contact.accountId = accounts[0].Id;
		}
		insert contact;

		System.debug('Contact created for ' + data.email + ' id=' + contact.id);

		return contact.id;
	}


	/**
	 * Create and initialize the User but don't save it yet
	 *
	 * @param data - the provided User context from FaceBook
	 * @param p - the Profile we are going to assign to this user
	 *
	 * @return User that has been initialized but not Saved
	 **/
	private User createUser(Auth.UserData data, Profile p) {
		User u = new User();
		u.username = data.email + ORG_SUFFIX;
		u.email = data.email;
		u.lastName = data.lastName;
		u.firstName = data.firstName;
		String alias = data.firstName + data.lastName;

		//Alias must be 8 characters or less
		if(alias.length() > 8) {
			alias = alias.substring(0, 8);
		}
		u.alias = alias;
		u.languagelocalekey = 'it';
		u.localesidkey = 'it_IT';
		u.emailEncodingKey = 'UTF-8';
		u.timeZoneSidKey = 'GMT';
		u.profileId = p.Id;
		u.Origin__c = 'Facebook';
		u.Registration_status__c = 'Incomplete';
		return u;
	}
}