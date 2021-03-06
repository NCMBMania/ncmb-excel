VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "clsRequest"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
Private m_NCMB As clsNCMB

Private Sub Class_Initialize()
End Sub

Property Let ncmb(ByVal ncmb As clsNCMB)
    Set m_NCMB = ncmb
End Property

Public Function GetRequest(className As String, queries As Dictionary) As Dictionary
    Set GetRequest = SendRequest("GET", className, New Dictionary, queries)
End Function

Public Function PostRequest(className As String, fields As Dictionary) As Dictionary
    Set PostRequest = SendRequest("POST", className, fields, New Dictionary)
End Function

Public Function PutRequest(className As String, fields As Dictionary) As Dictionary
    Set PutRequest = SendRequest("PUT", className, fields, New Dictionary)
End Function

Public Function DeleteRequest(className As String, fields As Dictionary) As Dictionary
    Set DeleteRequest = SendRequest("DELETE", className, fields, New Dictionary)
End Function

Private Function SendRequest(method As String, className As String, fields As Dictionary, queries As Dictionary) As Dictionary
    Dim path As String
    If className = "login" Then
        path = "/" & m_NCMB.Version & "/" & className
    Else
        path = "/" & m_NCMB.Version & "/classes/" & className
    End If
    If method = "PUT" Or method = "DELETE" Then
        path = path & "/" & fields("objectId")
        fields.Remove ("objectId")
    End If
    
    Dim signature As String
    Dim thisTime As Date
    thisTime = Date
    signature = generateSignature(path, method, queries, thisTime)
        
    Dim httpReq As Object
    Set httpReq = CreateObject("MSXML2.ServerXMLHTTP.6.0")
    Dim url As String
    url = m_NCMB.Protocol & "//" & m_NCMB.Fqdn & path
    If method = "GET" Then
        url = url & "?" & Dic2Encode(queries, True)
    End If
    httpReq.Open method, url, False
    
    If m_NCMB.SessionToken <> "" Then
        Debug.Print m_NCMB.SessionToken
        httpReq.setRequestHeader "X-NCMB-Apps-Session-Token", m_NCMB.SessionToken
    End If
    
    httpReq.setRequestHeader "X-NCMB-Application-Key", m_NCMB.ApplicationKey
    httpReq.setRequestHeader "X-NCMB-Timestamp", UtcConverter.ConvertToIso(thisTime)
    httpReq.setRequestHeader "X-NCMB-Signature", signature
    httpReq.setRequestHeader "Content-Type", "application/json"
        
    If method = "GET" Then
        httpReq.send
    Else
        httpReq.send (JsonConverter.ConvertToJson(fields))
    End If
    
    Dim json As Object
    If method = "DELETE" And httpReq.responseText = "" Then
        Set SendRequest = New Dictionary
    Else
        Set SendRequest = JsonConverter.ParseJson(httpReq.responseText)
    End If
End Function

Public Function Dic2Encode(Data As Object, encode As Boolean) As String
    Dim ary() As String
    i = 0
    For Each key In Data
        ReDim Preserve ary(i)
        If VarType(Data(key)) = vbObject Then
            Dim value As String
            value = JsonConverter.ConvertToJson(Data(key))
        Else
            value = Data(key)
        End If
        If encode Then
            value = Application.WorksheetFunction.encodeUrl(value)
        End If
        ary(i) = key & "=" & value
        i = i + 1
    Next
    Dic2Encode = Join(ary, "&")
End Function

Public Function generateSignature(path As String, method As String, queries As Dictionary, timestamp As Date) As String
     
    Dim Data As Dictionary
    Set Data = New Dictionary
    
    Data.Add "SignatureMethod", m_NCMB.SignatureMethod
    Data.Add "SignatureVersion", m_NCMB.SignatureVersion
    Data.Add "X-NCMB-Application-Key", m_NCMB.ApplicationKey
    Data.Add "X-NCMB-Timestamp", UtcConverter.ConvertToIso(timestamp)
    
    
    Dim i As Integer
    For Each key In queries
        If VarType(queries(key)) = vbObject Then
            Data.Add key, Application.WorksheetFunction.encodeUrl(JsonConverter.ConvertToJson(queries(key)))
        Else
            Data.Add key, Application.WorksheetFunction.encodeUrl(queries(key))
        End If
    Next key
    
    Call DicSort(Data)
    
    Dim sigStr(3) As String
    sigStr(0) = method
    sigStr(1) = m_NCMB.Fqdn
    sigStr(2) = path
    sigStr(3) = Dic2Encode(Data, False)
    
    ' Debug.Print Join(sigStr, vbLf)
    generateSignature = Base64_HMACSHA256(Join(sigStr, vbLf), m_NCMB.ClientKey)
End Function


Public Function Base64_HMACSHA256(ByVal sTextToHash As String, ByVal sSharedSecretKey As String)

    Dim asc As Object, enc As Object
    Dim TextToHash() As Byte
    Dim SharedSecretKey() As Byte
    Set asc = CreateObject("System.Text.UTF8Encoding")
    Set enc = CreateObject("System.Security.Cryptography.HMACSHA256")

    TextToHash = asc.Getbytes_4(sTextToHash)
    SharedSecretKey = asc.Getbytes_4(sSharedSecretKey)
    enc.key = SharedSecretKey

    Dim bytes() As Byte
    bytes = enc.ComputeHash_2((TextToHash))
    Base64_HMACSHA256 = EncodeBase64(bytes)
    Set asc = Nothing
    Set enc = Nothing

End Function

Private Function EncodeBase64(ByRef arrData() As Byte) As String

    Dim objXML As MSXML2.DOMDocument
    Dim objNode As MSXML2.IXMLDOMElement

    Set objXML = New MSXML2.DOMDocument

    ' byte array to base64
    Set objNode = objXML.createElement("b64")
    objNode.DataType = "bin.base64"
    objNode.nodeTypedValue = arrData
    EncodeBase64 = objNode.Text

    Set objNode = Nothing
    Set objXML = Nothing

End Function

' Dictionaryを参照引数にし、これをソートする破壊的プロシージャ。
Sub DicSort(ByRef dic As Object)
  Dim i As Long, j As Long, dicSize As Long
  Dim varTmp() As String

  dicSize = dic.Count

  ReDim varTmp(dicSize + 1, 2)

  ' Dictionaryが空か、サイズが1以下であればソート不要
  If dic Is Nothing Or dicSize < 2 Then
    Exit Sub
  End If

  ' Dictionaryから二元配列に転写
  i = 0
  For Each key In dic
    varTmp(i, 0) = key
    varTmp(i, 1) = dic(key)
    i = i + 1
  Next

  'クイックソート
  Call QuickSort(varTmp, 0, dicSize - 1)

  dic.RemoveAll

  For i = 0 To dicSize - 1
    dic(varTmp(i, 0)) = varTmp(i, 1)
  Next
End Sub


'' String型で2列の二次元配列を受け取り、これの1列目でクイックソートする（ほんとはCompareメソッドを渡すAdapterパターンで書きたいところ、VBAのオブジェクト指向厳しい感じで妥協）
Private Sub QuickSort(ByRef targetVar() As String, ByVal min As Long, ByVal max As Long)
    Dim i, j As Long
    Dim tmp As String

    If min < max Then
        i = min
        j = max
        pivot = strMed3(targetVar(i, 0), targetVar(Int(i + j / 2), 0), targetVar(j, 0))
        Do
            Do While StrComp(targetVar(i, 0), pivot) < 0
                i = i + 1
            Loop
            Do While StrComp(pivot, targetVar(j, 0)) < 0
                j = j - 1
            Loop
            If i >= j Then Exit Do

            tmp = targetVar(i, 0)
            targetVar(i, 0) = targetVar(j, 0)
            targetVar(j, 0) = tmp

            tmp = targetVar(i, 1)
            targetVar(i, 1) = targetVar(j, 1)
            targetVar(j, 1) = tmp

            i = i + 1
            j = j - 1

        Loop
        Call QuickSort(targetVar, min, i - 1)
        Call QuickSort(targetVar, j + 1, max)

    End If
End Sub


'' String型のx, y, z を辞書順比較し二番目のものを返す
Private Function strMed3(ByVal x As String, ByVal y As String, ByVal z As String)
    If StrComp(x, y) < 0 Then
        If StrComp(y, z) < 0 Then
            strMed3 = y
        ElseIf StrComp(z, x) < 0 Then
            strMed3 = x
        Else
            strMed3 = z
        End If
    Else
        If StrComp(z, y) < 0 Then
            strMed3 = y
        ElseIf StrComp(x, z) < 0 Then
            strMed3 = x
        Else
            strMed3 = z
        End If
    End If
End Function
