/*
用于将xmltype转换为json
例：
create table tt3 (c xmltype);
create table tt2 (c clob);
*/
DECLARE
  --测试参数
  xml_req      XMLTYPE;
  document_req dbms_xmldom.DOMDocument;
  node_req     dbms_xmldom.DOMNode;
  vv           CLOB;
  --常量,示例：
  --<a>1</a> ==> "a":"1"
  TYPE_ELEMENT  CONSTANT INTEGER := 0;
  --<a><b>1</b>..</a> ==> "a":{"b":"1",..}
  TYPE_OBJECT   CONSTANT INTEGER := 1;
  --<a>1</a><a>2</a> ==> "a":["1","2"]
  --TYPE_ARRAY    CONSTANT INTEGER := 2;
  
  --JSONArray开始，需包“[”
  TYPE_ARRAY_HEAD CONSTANT INTEGER := 1;
  --JSONArray中段，不需名称
  TYPE_ARRAY_BODY CONSTANT INTEGER := 2;
  --JSONArray结束，需包“]”
  TYPE_ARRAY_END  CONSTANT INTEGER := 3;
  /*-----------------------------------------------------------------------------------------------
  || 函数名称：fun_appendClob
  || 功能描述：clob添加，因DBMS_LOB.APPEND要求不能为空
  ||----------------------------------------------------------------------------------------------*/
  FUNCTION fun_appendClob(prm_desc IN CLOB, prm_src IN CLOB) RETURN CLOB IS
    rtn_clob CLOB := prm_desc;
  BEGIN
    IF prm_src IS NOT NULL AND DBMS_LOB.GETLENGTH(prm_src) > 0 THEN
      IF prm_desc IS NULL OR DBMS_LOB.GETLENGTH(prm_desc) = 0 THEN
        rtn_clob := prm_src;
      ELSE
        DBMS_LOB.APPEND(rtn_clob, prm_src);
      END IF;
    END IF;
    RETURN rtn_clob;
  END;
  /*-----------------------------------------------------------------------------------------------
  || 函数名称：fun_traversing
  || 功能描述：遍历Node转换为JSON
  ||----------------------------------------------------------------------------------------------*/
  FUNCTION fun_traversing(prm_node      IN DBMS_XMLDOM.DOMNode,
                          prm_jsonType  IN INTEGER DEFAULT 1,
                          prm_arrayType IN INTEGER DEFAULT 0) RETURN ClOB IS
    c_rtnJSON     CLOB;
    v_nodeValue   VARCHAR2(2000);
    v_nodeName    VARCHAR2(30);
    v_nodeType    NUMBER;
    childList     dbms_xmldom.DOMNODELIST;
    childListSize NUMBER;
    childNode     dbms_xmldom.domnode;
    lastChildNode dbms_xmldom.domnode;
    nextChildNode dbms_xmldom.domnode;
    i_jsonType    INTEGER;
    i_arrayType   INTEGER;
  BEGIN
    v_nodeName := dbms_xmldom.getNodeName(prm_node);
    v_nodeType := dbms_xmldom.getNodeType(prm_node);
    --区分元素类型,Document视同Object但不取名称，Element为Object，Text只取值
    IF v_nodeType = dbms_xmldom.DOCUMENT_NODE THEN
      NULL;
    ELSIF v_nodeType IN (dbms_xmldom.ELEMENT_NODE, dbms_xmldom.DOCUMENT_NODE) THEN
      --名称
      IF prm_arrayType NOT IN (TYPE_ARRAY_BODY, TYPE_ARRAY_END) THEN
        c_rtnJSON := fun_appendClob(c_rtnJSON, '"' || v_nodeName || '":');
        --数组类型，除首个外均不需名称
        IF prm_arrayType = TYPE_ARRAY_HEAD THEN
          c_rtnJSON := fun_appendClob(c_rtnJSON, '[');
        END IF;
      END IF;
    ELSIF v_nodeType = dbms_xmldom.TEXT_NODE THEN
      --文本类型，取值，结束退出
      v_nodeValue := DBMS_XMLDOM.GETNODEVALUE(prm_node);
      c_rtnJSON := fun_appendClob(c_rtnJSON, '"' || v_nodeValue || '",');
      RETURN c_rtnJSON;
    END IF;
    --对象类型，包“{”
    IF prm_jsonType = TYPE_OBJECT THEN
      c_rtnJSON := fun_appendClob(c_rtnJSON, '{');
    END IF;
    --子集
    childList     := dbms_xmldom.getChildNodes(prm_node);
    childListSize := dbms_xmldom.getLength(childList);
    --无值元素的处理，例：<ELE/>
    IF childListSize = 0 AND v_nodeType = dbms_xmldom.ELEMENT_NODE THEN
      c_rtnJSON := fun_appendClob(c_rtnJSON, '"",');
    END IF;
    --遍历子节点，递归解析
    FOR i IN 0 .. (childListSize - 1) LOOP
      --重置变量，释放资源
      DBMS_XMLDOM.FREENODE(nextChildNode);
      DBMS_XMLDOM.FREENODE(lastChildNode);
      DBMS_XMLDOM.FREENODE(childNode);
      i_arrayType := 0;
      --子节点
      childNode := dbms_xmldom.item(childList, i);
      --子节点若为元素类型，深入解析
      IF dbms_xmldom.getNodeType(childNode) = dbms_xmldom.ELEMENT_NODE THEN
        --长孙节点为元素，则该子节点为对象
        IF dbms_xmldom.getNodeType(DBMS_XMLDOM.GETFIRSTCHILD(childNode)) = dbms_xmldom.ELEMENT_NODE THEN
          i_jsonType := TYPE_OBJECT;
        ELSE
          i_jsonType := TYPE_ELEMENT;
        END IF;
        --判断是否为数组
        --下一个节点
        IF i < childListSize - 1 THEN
          nextChildNode := dbms_xmldom.item(childList, i + 1);
        END IF;
        --上一个节点
        IF i > 0 THEN
          lastChildNode := dbms_xmldom.item(childList, i - 1);
        END IF;
        --如果与前后节点名称相同
        IF (NOT DBMS_XMLDOM.ISNULL(nextChildNode) AND DBMS_XMLDOM.GETNODENAME(nextChildNode) = DBMS_XMLDOM.GETNODENAME(childNode)) OR 
           (NOT DBMS_XMLDOM.ISNULL(lastChildNode) AND DBMS_XMLDOM.GETNODENAME(lastChildNode) = DBMS_XMLDOM.GETNODENAME(childNode)) THEN
          --Array第一个节点
          IF DBMS_XMLDOM.GETNODENAME(lastChildNode) != DBMS_XMLDOM.GETNODENAME(childNode) THEN
            i_arrayType := TYPE_ARRAY_HEAD;
          ELSIF DBMS_XMLDOM.GETNODENAME(nextChildNode) != DBMS_XMLDOM.GETNODENAME(childNode) THEN
            --最后一个节点
            i_arrayType := TYPE_ARRAY_END;
          ELSE  
            --数组中段
            i_arrayType := TYPE_ARRAY_BODY;
          END IF;
        END IF;
      END IF;
      c_rtnJSON := fun_appendClob(c_rtnJSON, fun_traversing(childNode, i_jsonType, i_arrayType));
    END LOOP;
    --对象类型，截去末尾","后添加结束符“}”
    IF prm_jsonType = TYPE_OBJECT THEN
      c_rtnJSON := regexp_replace(c_rtnJSON, ',$', '');
      c_rtnJSON := fun_appendClob(c_rtnJSON, '},');
    END IF;
    --数组类型，截去末尾","后添加结束符“]”
    IF prm_arrayType = TYPE_ARRAY_END THEN
      c_rtnJSON := regexp_replace(c_rtnJSON, ',$', '');
      c_rtnJSON := fun_appendClob(c_rtnJSON, '],');
    END IF;
    --DOCUMENT类型返回时，再次截去末尾","
    IF v_nodeType = dbms_xmldom.DOCUMENT_NODE THEN
      c_rtnJSON := regexp_replace(c_rtnJSON, ',$', '');
    END IF;
    RETURN c_rtnJSON;
  END;
BEGIN
  SELECT c INTO xml_req FROM TT3 WHERE ROWNUM = 1;
  document_req := DBMS_XMLDOM.newdomdocument(xml_req);
  node_req     := dbms_xmldom.makenode(document_req);
  vv           := fun_traversing(node_req);
  insert into tt2 (c) values (vv);
END;