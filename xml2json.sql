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
  jsonType     integer := 0;
  type_Element  constant integer := 0;
  type_Object   constant integer := 1;
  type_Array    constant integer := 2;
  type_ArrayEle constant integer := 3;
  type_ArrayObj constant integer := 4;
  FUNCTION fun_getNodeValue(prm_node         IN DBMS_XMLDOM.DOMNode,
                            prm_jsonType     in integer default 1,
                            prm_lastNodeName in varchar2 default '')
    RETURN VARCHAR2 IS
    v_nodeValue    VARCHAR2(2000);
    v_nodeName     varchar2(30);
    v_nodeType     number;
    childList      dbms_xmldom.DOMNODELIST;
    childListSize  number;
    childNode      dbms_xmldom.domnode;
    subChildList   dbms_xmldom.DOMNODELIST;
    v_lastNodeName varchar2(30);
    i_jsonType     integer;
  BEGIN
    v_nodeName := dbms_xmldom.getNodeName(prm_node);
    v_nodeType := dbms_xmldom.getNodeType(prm_node);
    --区分元素类型
    if v_nodeType = dbms_xmldom.DOCUMENT_NODE then
      i_jsonType := type_Object;
    elsif v_nodeType = dbms_xmldom.ELEMENT_NODE then
      --元素类型，只取名称
      dbms_output.put_line('"' || v_nodeName || '"<---->' || prm_jsonType);
      if prm_jsonType not in (type_ArrayEle, type_ArrayObj) then
        --JSONArray的元素，不再重复取名称
        v_nodeValue := '"' || v_nodeName || '":';
        if prm_jsonType = type_Array then
          --JSONArray类型，名称包含子元素名称
          v_nodeValue := v_nodeValue || '{"';
          v_nodeValue := v_nodeValue ||
                         dbms_xmldom.getNodeName(DBMS_XMLDOM.GETFIRSTCHILD(prm_node)) ||
                         '":[';
        end if;
      end if;
    elsif v_nodeType = dbms_xmldom.TEXT_NODE then
      --文本类型，取值，结束退出
      v_nodeValue := DBMS_XMLDOM.GETNODEVALUE(prm_node);
      v_nodeValue := '"' || v_nodeValue || '",';
      return v_nodeValue;
    end if;
    --JSONObject用“{”包裹值部分
    if prm_jsonType in (type_Object, type_ArrayObj) then
      v_nodeValue := v_nodeValue || '{';
    end if;
    childList     := dbms_xmldom.getChildNodes(prm_node);
    childListSize := dbms_xmldom.getLength(childList);
    --遍历子节点，递归解析
    for i in 0 .. (childListSize - 1) loop
      childNode := dbms_xmldom.item(childList, i);
      --子节点和长孙节点均为元素类型，深入解析
      if dbms_xmldom.getNodeType(childNode) = dbms_xmldom.ELEMENT_NODE and
         dbms_xmldom.getNodeType(DBMS_XMLDOM.GETFIRSTCHILD(childNode)) =
         dbms_xmldom.ELEMENT_NODE then
        --孙子节点，用于判断子节点是否为JSONArray
        subChildList := dbms_xmldom.getChildNodes(childNode);
        --孙子节点不止1个，且首尾同名，视为JSONArray
        --！！！此处未考虑（size = 1）的JSONArray
        if dbms_xmldom.getLength(subChildList) > 1 and
           dbms_xmldom.getNodeName(DBMS_XMLDOM.GETFIRSTCHILD(childNode)) =
           dbms_xmldom.getNodeName(DBMS_XMLDOM.GETLASTCHILD(childNode)) then
          i_jsonType := type_Array;
        elsif prm_jsonType = type_Array then
          i_jsonType := type_ArrayObj;
        else
          i_jsonType := type_Object;
        end if;
      elsif prm_jsonType = type_Array then
        --如果当前为JSONArray，子元素进行特殊处理
        i_jsonType := type_ArrayEle;
      else
        i_jsonType := type_Element;
      end if;
      --if prm_jsonType = type_Array then
      --end if;
      v_nodeValue := v_nodeValue ||
                     fun_getNodeValue(childNode, i_jsonType, v_lastNodeName);
    end loop;
    --除元素类型，均截去最后一位的“,”
    if prm_jsonType not in (type_Element, type_ArrayEle) then
      v_nodeValue := regexp_replace(v_nodeValue, ',$', '');
    end if;
    --结束符
    v_nodeValue := v_nodeValue || case prm_jsonType
                     when type_Object then
                      '},'
                     when type_Array then
                      ']},'
                     when type_ArrayObj then
                      '},'
                   end;
    --二次截去，较前次增加ArrayObjcet类型
    if prm_jsonType not in (type_Element, type_ArrayEle, type_ArrayObj) then
      v_nodeValue := regexp_replace(v_nodeValue, ',$', '');
    end if;
    return v_nodeValue;
  END;
BEGIN
  select c into xml_req FROM TT3 WHERE ROWNUM = 1;
  document_req := DBMS_XMLDOM.newdomdocument(xml_req);
  node_req     := dbms_xmldom.makenode(document_req);
  vv           := fun_getNodeValue(node_req);
  dbms_output.put_line(vv);
END;