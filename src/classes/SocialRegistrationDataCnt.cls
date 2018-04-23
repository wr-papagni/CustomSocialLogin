/**
 * Created by papagni on 23/04/2018.
 */

public without sharing class SocialRegistrationDataCnt {

	public String msgText {get; set;}
	public Map<String, String> mapParams {get; set;}
	public String identifier {get; set;}

	public void onload(){
		this.mapParams = ApexPages.currentPage().getParameters();

		if(!String.IsBlank(this.mapParams.get('data'))){
			String dati = EncodingUtil.base64Decode(this.mapParams.get('data')).toString();
			system.debug('###### dati:' + dati);
			Auth.UserData userData = (Auth.UserData) JSON.deserialize(dati, Auth.UserData.class);
			this.identifier = userData.identifier;
		}

		if(this.mapParams.get('action') != null && this.mapParams.get('action') == 'prof'){
			this.msgText = 'Controlla e compila i dati. quindi salva il Lead';
		}

		if(this.mapParams.get('action') != null && this.mapParams.get('action') == 'checkno'){
			this.msgText = 'Email registrazione non confermata. Reinvia.';
		}
	}
}