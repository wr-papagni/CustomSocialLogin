/**
 * Created by papagni on 23/04/2018.
 */

public without sharing class SocialRegistrationCtn {

	public Map<String, String> mapParams {get; set;}
	public String oauthToken {get; set;}
	public String identifier {get; set;}

	private Auth.AuthProviderTokenResponse authTokResponse;
	private Auth.UserData userData;

	public PageReference onload(){
		this.mapParams = ApexPages.currentPage().getParameters();
		this.authTokResponse = handleCallback(authProviderConfiguration, mapParams); //effettuo la chiamata per ricevere l'access token
		this.userData = getUserInfo(authProviderConfiguration, this.authTokResponse); //effettuo la chiamata per ricevere i dati dell'utente

		this.oauthToken = authTokResponse.oauthToken;
		this.identifier = userData.identifier;

		return this.businessLogic(); //decido dove rimandare l'utente
	}

	private Map<String, String> authProviderConfiguration;
	public SocialRegistrationCtn(){
		this.loadConfiguration();
	}

	/* Carica i parametri necessari dal Custom Metadata in modo che i vari metodi vi possono accedere e recuperare i dati che servono.
	*/
	private void loadConfiguration(){
		Social__mdt socialmdt = [select id, Key__c,
			Secret__c,
			Access_Token_Url__c,
			API_User_Url__c,
			API_User_Version_Url__c,
			Auth_Url__c,
			Redirect_Url__c
		From Social__mdt];

		this.authProviderConfiguration = new Map<String,String>{
			'Key__c' => socialmdt.Key__c,
			'Secret__c' => socialmdt.Secret__c,
			'Access_Token_Url__c' => socialmdt.Access_Token_Url__c,
			'API_User_Url__c' => socialmdt.API_User_Url__c,
			'API_User_Version_Url__c' => socialmdt.API_User_Version_Url__c,
			'Auth_Url__c' => socialmdt.Auth_Url__c,
			'Redirect_Url__c' => socialmdt.Redirect_Url__c
		};
	}

	/*  Dopo che l'utente ha inserito le credenzili in Facebook, viene chiamata la Url di callback.
		Questo metodo serve per ottenere un access token con cui poi sarà possibile ricevere i dati del cliente.
	*/
	public Auth.AuthProviderTokenResponse handleCallback(Map<string,string> authProviderConfiguration, Map<String, String> parameters ) {
		//Here, the developer will get the callback with actual protocol.
		//Their responsibility is to return a new object called AuthProviderToken
		//This will contain an optional accessToken and refreshToken
		String key = authProviderConfiguration.get('Key__c');
		String secret = authProviderConfiguration.get('Secret__c');
		String accessTokenUrl = authProviderConfiguration.get('Access_Token_Url__c');
		String redirectUrl = authProviderConfiguration.get('Redirect_Url__c');

		String code = parameters.get('code');
		String sfdcState = parameters.get('state');

		HttpRequest req = new HttpRequest();
		//String url = accessTokenUrl+'?code=' + code + '&client_id=' + key + '&client_secret=' + secret;
		String url = accessTokenUrl+'?code=' + code + '&client_id=' + key + '&client_secret=' + secret + '&redirect_uri=' + EncodingUtil.urlEncode(redirectUrl, 'UTF-8');
		system.debug('#### url:'+url);
		req.setEndpoint(url);
		//req.setHeader('Content-Type','application/xml');
		req.setHeader('Content-Type','application/json');
		req.setMethod('GET');

		Http http = new Http();
		HTTPResponse res = http.send(req);
		String responseBody = res.getBody();
		system.debug('###responseBody:'+responseBody);
		//String token = getTokenValueFromResponse(responseBody, 'Token', null);
		Map<String, Object> m = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
		String token = (String)m.get('access_token');
		system.debug('##token:'+token);

		return new Auth.AuthProviderTokenResponse('Concur', token, 'refreshToken', sfdcState);
	}

	/*  Una volta ottenuto l'access token, è possibile chiamare l'endpoint di Facebook per farsi restituire i dati del cliente
	*/
	public Auth.UserData getUserInfo(Map<string,string> authProviderConfiguration, Auth.AuthProviderTokenResponse response) {
		//Here the developer is responsible for constructing an Auth.UserData object
		String token = response.oauthToken;
		HttpRequest req = new HttpRequest();
		String userAPIUrl = authProviderConfiguration.get('API_User_Url__c');
		String userAPIVersionUrl = authProviderConfiguration.get('API_User_Version_Url__c');
		req.setHeader('Authorization', 'OAuth ' + token);
		req.setEndpoint(userAPIUrl);
		//req.setHeader('Content-Type','application/xml');
		req.setHeader('Content-Type','application/json');
		req.setMethod('GET');

		Http http = new Http();
		HTTPResponse res = http.send(req);
		String responseBody = res.getBody();
		system.debug('##### responseBody:'+responseBody);
		Map<String, Object> m = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
		String id = (String)m.get('id');
		String fname = (String)m.get('first_name');
		String lname = (String)m.get('last_name');
		String flname = fname + ' ' + lname;
		String uname = (String)m.get('email');
		String locale = (String)m.get('LocaleName');
		Map<String,String> provMap = new Map<String,String>();
		provMap.put('what1', 'noidea1');
		provMap.put('what2', 'noidea2');
		provMap.put('identifier', (String)m.get('id'));
		Auth.UserData Authd = new Auth.UserData(id, fname, lname, flname, uname,
			'what', locale, null, 'Concur', null, provMap);
		system.debug('##### Authd:'+Authd);
		return Authd;
	}

	/* Questo metodo decide dove rimandare l'utente una volta ottenuti i suoi dati da Facebook.
		Per esempio controllo se con quei dati esiste già un Lead a sistema.
		Se non esiste rimando su una pagina dove inserire i dati mancanti per la registrazione e poi salvare il Lead.
		Se esiste faccio le verifiche sullo stato della registrazione dell'utente e mostro un messaggio di conseguenza.
	*/
	public PageReference businessLogic(){
		PageReference p = Page.SocialRegistrationData;

		String dataObj = EncodingUtil.base64Encode(Blob.valueOf(Json.serialize(this.userData)));

		String action;
		List<Lead> lLead = [select id, email, Facebook_remote_identifier__c from Lead where email=: userData.email];
		if(lLead.size() > 0){
			//check Token email verifica
			action = 'checkno'; //email non verificata
			p.getParameters().put('lead', lLead[0].Id);
		}
		else{
			//redirect to complete data profile
			action = 'prof';
		}

		p.getParameters().put('data', dataObj);
		p.getParameters().put('action', action);
		p.setRedirect(true);
		system.debug('####businessLogic exit');
		return p;
	}

	/*  Costruisce la URL per avviare l'autenticazione su Facebook
		stateToPropagate= codice anti CSRF attac. Nella Auth.AuthProviderPluginClass.Initiate() il codice è staccato dall'Auth provider secondo logiche non note.
	*/
	public PageReference goFacebook(){
		String redirectUrl = authProviderConfiguration.get('Redirect_Url__c');
		String stateToPropagate = EncodingUtil.base64Encode(Blob.valueOf('PROVA123')); //code anti CSRF attac!!

		String authUrl = authProviderConfiguration.get('Auth_Url__c');
		String key = authProviderConfiguration.get('Key__c');
		String url = 'https://www.facebook.com/login.php?skip_api_login=1&api_key=185675338890967&signed_next=1';
		url += '&next=' + EncodingUtil.urlEncode(authUrl + '?client_id='+ key +'&scope=email&response_type=code&redirect_uri='+ redirectUrl + '&state=' + stateToPropagate, 'UTF-8');
		system.debug('##url:'+url);
		PageReference p = new PageReference(url);
		p.setRedirect(true);
		return p;
	}

}