// GOOD: LDAP connection using LDAPS
String ldapUrl = "ldaps://ad.your-server.com:636";
Hashtable<String, String> environment = new Hashtable<String, String>();
environment.put(Context.INITIAL_CONTEXT_FACTORY, "com.sun.jndi.ldap.LdapCtxFactory");
environment.put(Context.PROVIDER_URL, ldapUrl);
environment.put(Context.REFERRAL, "follow");
environment.put(Context.SECURITY_AUTHENTICATION, "simple");
environment.put(Context.SECURITY_PRINCIPAL, ldapUserName);
environment.put(Context.SECURITY_CREDENTIALS, password);
DirContext dirContext = new InitialDirContext(environment);
