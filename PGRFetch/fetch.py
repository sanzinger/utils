# coding: utf8
import mechanize, urllib, logging, sys, md5
from bs4 import BeautifulSoup

class Interface:
    def __init__(self, url):
        self._b = mechanize.Browser()
        #self._b.set_debug_http(True)
        #self._b.set_debug_responses(True)
        #self._b.set_debug_redirects(True)
        self._url = url
        self._loggedin = False
        
    def login(self, u, p):
        b = self._b
        b.open(self._url)
        b.select_form("form_contents")
        f = b.form
        f.find_control("user_name").value = u
        
        """isPwField = lambda f: f != None and f.name != None and "password_" in f.name
        pwf = [c for c in f.controls if isPwField(c)]
        assert len(pwf)==1
        pwf[0].value = p"""
        f.set_all_readonly(False)
        auth_key = f.find_control("auth_key").value
        f.find_control("md5_pass").value = md5.new(p + auth_key).hexdigest()
        f.find_control("md5_pass_clear").value = md5.new(p).hexdigest()
        f.find_control("mimic_button_field").value = "submit_button_login_submit: .."
        resp = b.submit()
        cont = resp.read()
        self._b.response()
        assert cont.count("Recovery")>0
        self._loggedin = True
    
    def _mimic(self, m):
        assert self._loggedin
        self._b.select_form("form_contents")
        f=self._b.form
        f.set_all_readonly(False)
        f.find_control("mimic_button_field").value = m
        return self._b.submit()
    
    def logout(self):
        resp = self._mimic("sidebar: sidebar_logout..")
        assert resp.read().count("Anmeldung")>0
        self._loggedin = False
    
    def getTrafficStats(self):
        resp = self._mimic("sidebar: sidebar_monitoring..")
        cont = resp.read()
        assert cont.count("LAN Bridge") > 0
        b = BeautifulSoup(cont)
        def readRow(txt):
            t = b.find("td", text=txt)
            return list(t.parent.strings)[1:]
        recv = readRow("Empfangene Bytes")
        recv_p = readRow("Empfangene Pakete")
        sent = readRow("Gesendete Bytes")
        sent_p = readRow("Empfangene Pakete")
        names = readRow("Gerätename")
        r = {}
        for i in range(1,len(names)):
            if(recv[i] != None and recv[i].strip() != ''):
                r[names[i]] = {'rx': int(recv[i]), 
                               'tx': int(sent[i]),
                               'rx_p': int(recv_p[i]),
                               'tx_p': int(sent_p[i])}
                               
        return r
        
if __name__ == "__main__":
    i = Interface("http://192.168.0.10/")
    try:
        i.login(sys.argv[1], sys.argv[1])
        print i.getTrafficStats()
    finally:
        i.logout()
    