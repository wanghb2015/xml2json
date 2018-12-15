/*
用于将xmltype转换为json
例：
create table tt3 (c xmltype);
create table tt2 (c clob);
*/
DECLARE
  xml_req      xmltype;
  document_req dbms_xmldom.DOMDocument;
  node_req     dbms_xmldom.DOMNode;
  vv           varchar2(2000);
  FUNCTION fun_getNodeValue(prm_node IN DBMS_XMLDOM.DOMNode) RETURN VARCHAR2 IS
    v_nodeValue   VARCHAR2(2000);
    v_nodeName    varchar2(30);
    v_nodeType    number;
    childList     dbms_xmldom.DOMNODELIST;
    childListSize number;
  BEGIN
    v_nodeValue := DBMS_XMLDOM.GETNODENAME(prm_node);
    v_nodeName  := dbms_xmldom.getNodeName(prm_node);
    v_nodeType  := dbms_xmldom.getNodeType(prm_node);
    dbms_output.put_line(v_nodeName || '<--->' || v_nodeType || '<--->' ||
                         v_nodeValue);
    childList     := dbms_xmldom.getChildNodes(prm_node);
    childListSize := dbms_xmldom.getLength(childList);
    for i in 0 .. (childListSize - 1) loop
      v_nodeValue := fun_getNodeValue(dbms_xmldom.item(childList, i));
    end loop;
    return v_nodeValue;
  END;
BEGIN
  select c into xml_req FROM TT3 WHERE ROWNUM = 1;
  document_req := DBMS_XMLDOM.newdomdocument(xml_req);
  node_req     := dbms_xmldom.makenode(document_req);
  vv           := fun_getNodeValue(node_req);
END;